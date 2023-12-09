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
        <a href={~p"/uploads/#{Path.basename(@audio_path)}"}>
          Download Audio
        </a>
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
      consume_uploaded_entry(socket, entry, fn meta ->
        video_output_path = Path.join("priv/static/uploads", Path.basename(meta.path))
        File.cp(meta.path, video_output_path)

        gen = VideoProcessor.open(input_path: video_output_path, caller: self())

        {:ok,
         socket
         |> assign(gen: gen)}
      end)
    end

    {:noreply,
     socket
     |> assign(message: "Demuxing...")}
  end

  def handle_event("validate", _arams, socket) do
    {:noreply,
     socket
     |> assign(message: "Uploading Video...")}
  end

  def handle_info({_ref, :ok, audio_path}, socket) do
    {:noreply,
     socket
     |> assign(message: "Done! 🥳")
     |> assign(audio_path: audio_path)}
  end
end
