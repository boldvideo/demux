defmodule DemuxWeb.HomeLive do
  alias Demux.VideoProcessor
  use DemuxWeb, :live_view

  # alias DemuxWeb.Router.Helpers, as: Routes

  require Logger

  def render(assigns) do
    ~H"""
    <.form for={%{}} phx-change="validate" phx-submit="save">
      <div class="space-y-4 relative">
        <h1 class="text-xl"><%= @message %></h1>
        <.live_file_input upload={@uploads.video} />
        <div :for={entry <- @uploads.video.entries}>
          <div class="w-full bg-gray-200 rounded-full h-2.5">
            <div class="bg-blue-600 h-2.5 rounded-full" style={"width: #{entry.progress}%"}></div>
          </div>
        </div>
      </div>
      <%= if assigns[:audio_path] do %>
        <audio controls>
          <source src={~p"/uploads/#{Path.basename(@audio_path)}"} type="audio/mpeg" />
        </audio>
        <a href={~p"/uploads/#{Path.basename(@audio_path)}"}>Download</a>
      <% end %>
    </.form>
    """
  end

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(message: "Upload a video to Demux")
     |> allow_upload(:video,
       accept: ~w(.mp4),
       max_file_size: 524_288_000,
       max_entries: 1,
       # # 256kb
       # chunk_size: 262_144,
       progress: &handle_progress/3,
       auto_upload: true
     )}
  end

  def handle_progress(:video, entry, socket) do
    if entry.done? do
      video_output_path =
        Path.join(upload_path(), Ecto.UUID.generate())

      Logger.info("File Upload done. Copying file to #{video_output_path}")

      # audio_output_path =
      #   Path.join(upload_path(), Ecto.UUID.generate())

      consume_uploaded_entry(socket, entry, fn meta ->
        File.cp(meta.path, video_output_path)

        Logger.info("Starting demuxing process...")
        VideoProcessor.open(input_path: video_output_path, caller: self())
        Logger.info("Demuxing initiated...")

        {:ok, :ok}
      end)

      Logger.info("upload done")

      {:noreply,
       socket
       # |> assign(audio_output_path: audio_output_path)
       |> assign(file: Path.basename(video_output_path))
       |> assign(message: "Upload done...")}
    else
      {:noreply,
       socket
       |> assign(message: "Uploading...")}
    end
  end

  def handle_event("validate", _arams, socket) do
    {:noreply,
     socket
     |> assign(message: "Uploading Video...")}
  end

  def handle_info({_ref, :ok, audio_path}, socket) do
    Logger.info("audio path: #{audio_path}")
    Logger.info("assigngs path: #{socket.assigns.file}")

    File.cp(audio_path, Path.join(upload_path(), Path.basename(audio_path)))
    Logger.info("Audio File copied to #{Path.join(upload_path(), Path.basename(audio_path))}")

    {:noreply,
     socket
     |> assign(message: "Done! 🥳")
     |> assign(audio_path: socket.assigns.file <> ".mp3")}
  end

  defp upload_path do
    if System.get_env("FLY_APP_NAME") do
      "/app/uploads"
    else
      "priv/static/uploads"
    end
  end
end
