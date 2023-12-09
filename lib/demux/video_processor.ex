defmodule Demux.VideoProcessor do
  alias Demux.VideoProcessor
  use GenServer

  require Logger

  defstruct ref: nil, exec_pid: nil, caller: nil, pid: nil

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def open(opts \\ []) do
    Keyword.validate!(opts, [:timeout, :caller, :input_path])
    timeout = Keyword.get(opts, :timeout, 5_000)
    caller = Keyword.get(opts, :caller, self())
    parent_ref = make_ref()
    parent = self()

    spec = {__MODULE__, {caller, parent_ref, parent, opts}}
    {:ok, pid} = FLAME.place_child(Demux.FFMpegRunner, spec)

    receive do
      {^parent_ref, %VideoProcessor{} = gen} ->
        %VideoProcessor{gen | pid: pid}
    after
      timeout -> exit(:timeout)
    end
  end

  @impl true
  def init({caller, parent_ref, parent, opts}) do
    input_path = Keyword.get(opts, :input_path, "")
    tmp_audio_file = input_path <> ".mp3"

    ffmpeg_command = "ffmpeg -i #{input_path} -q:a 0 -map a #{tmp_audio_file}"

    case exec(ffmpeg_command) do
      {:ok, exec_pid, ref} ->
        Logger.info("ffmpeg runner started...")
        gen = %VideoProcessor{ref: ref, exec_pid: exec_pid, pid: self(), caller: caller}
        send(parent, {parent_ref, gen})
        Process.monitor(caller)
        {:ok, %{gen: gen, audio_file: tmp_audio_file, current: nil}}

      other ->
        Logger.error("Error starting ffmpeg: #{other}")
        exit(other)
    end
  end

  @impl true
  def handle_info({:stderr, _ref, _msg}, state) do
    {:noreply, state}
  end

  def handle_info({:stdout, _ref, _bin}, state) do
    {:noreply, state}
  end

  def handle_info({:DOWN, ref, :process, pid, reason}, state) do
    %{gen: %VideoProcessor{ref: gen_ref, caller: caller}} = state
    Logger.info("DOWN #{reason}")

    cond do
      pid === caller ->
        Logger.info("Caller #{inspect(pid)} went away: #{inspect(reason)}")
        {:stop, {:shutdown, reason}, state}

      ref === gen_ref ->
        Logger.info("Finished demuxing")
        send(caller, {ref, :ok, state.audio_file})

        {:stop, :normal, state}
    end
  end

  defp exec(cmd) do
    :exec.run(cmd, [:stdin, :stdout, :stderr, :monitor])
  end
end
