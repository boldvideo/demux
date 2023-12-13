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
    timeout = Keyword.get(opts, :timeout, 120_000)
    caller = Keyword.get(opts, :caller, self())
    parent_ref = make_ref()
    parent = self()

    input_file = Keyword.get(opts, :input_path, "")
    parent_stream = File.stream!(input_file, [], 2028)
    parent_audio_stream = File.stream!(input_file <> ".mp3", [], 2028)
    opts = opts ++ [parent_stream: parent_stream, parent_audio_stream: parent_audio_stream]

    spec = {__MODULE__, {caller, parent_ref, parent, opts}}
    Logger.info("Placing flame child...")
    {:ok, pid} = FLAME.place_child(Demux.FFMpegRunner, spec, timeout: 60_000)
    Logger.info("Placing flame child done. waiting for feedback")

    receive do
      {^parent_ref, %VideoProcessor{} = gen} ->
        Logger.info("Flame feedback received..")
        %VideoProcessor{gen | pid: pid}
    after
      timeout ->
        Logger.error("Timeout after #{timeout}")
        exit(:timeout)
    end
  end

  @impl true
  def init({caller, parent_ref, parent, opts}) do
    # input_path = Keyword.get(opts, :input_path, "")
    parent_stream = Keyword.get(opts, :parent_stream)
    parent_audio_stream = Keyword.get(opts, :parent_audio_stream)
    tmp_file = Path.join(System.tmp_dir!(), Ecto.UUID.generate())
    flame_stream = File.stream!(tmp_file)
    Enum.into(parent_stream, flame_stream)
    # tmp_audio_file = input_path <> ".mp3"
    tmp_audio_file = tmp_file <> ".mp3"

    # ffmpeg_command = "ffmpeg -i #{tmp_file} -q:a 0 -map a #{tmp_audio_file}"
    # ffmpeg_command = "ffmpeg -i #{tmp_file} -vn -acodec libmp3lame -b:a 320k #{tmp_audio_file}"
    ffmpeg_command =
      "ffmpeg -i #{tmp_file} -vn -acodec libmp3lame -ac 1 -ab 64k  #{tmp_audio_file}"

    # ffmpeg_command = "ffmpeg -i #{tmp_file} -vn -acodec aac -b:a 320k #{tmp_audio_file}"

    case exec(ffmpeg_command) do
      {:ok, exec_pid, ref} ->
        Logger.info("ffmpeg runner started...")
        gen = %VideoProcessor{ref: ref, exec_pid: exec_pid, pid: self(), caller: caller}
        send(parent, {parent_ref, gen})
        Process.monitor(caller)

        {:ok,
         %{
           gen: gen,
           audio_file: tmp_audio_file,
           parent_audio_stream: parent_audio_stream,
           current: nil
         }}

      other ->
        Logger.error("Error starting ffmpeg: #{other}")
        exit(other)
    end
  end

  @impl true
  def handle_info({:stderr, _ref, msg}, state) do
    Logger.info(msg)
    {:noreply, state}
  end

  def handle_info({:stdout, _ref, _bin}, state) do
    {:noreply, state}
  end

  def handle_info({:DOWN, _ref, :process, _pid, {:timeout, _}}, state) do
    Logger.error("FLAME Timout")
    {:noreply, state}
  end

  def handle_info({:DOWN, ref, :process, pid, reason}, state) do
    %{gen: %VideoProcessor{ref: gen_ref, caller: caller}} = state
    Logger.info("DOWN #{inspect(reason)}")

    cond do
      pid === caller ->
        Logger.info("Caller #{inspect(pid)} went away: #{inspect(reason)}")
        {:stop, {:shutdown, reason}, state}

      ref === gen_ref ->
        Logger.info("Finished demuxing #{state.audio_file}")
        flame_stream = File.stream!(state.audio_file)
        Enum.into(flame_stream, state.parent_audio_stream)
        send(caller, {ref, :ok, state.audio_file})

        {:stop, :normal, state}
    end
  end

  defp exec(cmd) do
    :exec.run(cmd, [:stdin, :stdout, :stderr, :monitor])
  end
end
