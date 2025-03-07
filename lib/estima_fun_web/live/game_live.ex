defmodule EstimaFunWeb.GameLive do
  alias EstimaFun.Game
  use Phoenix.LiveView
  alias EstimaFunWeb.GameComponents

  @topic_prefix "game:"

  def mount(_params, session, socket) do
    user_id = session["user_id"]
    default_name = "Player #{String.slice(user_id, 0..3)}"

    {:ok, assign(socket,
      user_id: user_id,
      current_answer: nil,
      default_name: default_name
    )}
  end

  def handle_params(%{"name" => name} = _params, _uri, socket) do
    if connected?(socket) do
      topic = @topic_prefix <> name
      IO.puts("Subscribing to topic: #{topic}")  # Debug line
      Phoenix.PubSub.subscribe(EstimaFun.PubSub, topic)
    end

    {:noreply, assign_game(socket, name)}
  end

  def handle_params(_params, _uri, socket) do
    name = generate_game_name()
    user_id = socket.assigns.user_id

    {:ok, _pid} =
      DynamicSupervisor.start_child(
        EstimaFun.GameSupervisor,
        {EstimaFun.GameServer, name: via_tuple(name), owner_id: user_id}
      )

    {:noreply, push_patch(socket, to: "/game?name=#{name}")}
  end

  def handle_event("join_game", %{"player_name" => name}, socket) do
    game = socket.assigns.game
    user_id = socket.assigns.user_id

    player = %{
      id: user_id,
      name: name,
      score: 0
    }

    EstimaFun.GameServer.join_game(via_tuple(socket.assigns.name), player)

    {:noreply, assign_game(socket)}
  end

  def handle_event("start_game", _params, %{assigns: %{game: game, user_id: user_id}} = socket) do
    if game.owner_id == user_id do
      EstimaFun.GameServer.start_game(via_tuple(socket.assigns.name))
    end

    {:noreply, assign_game(socket)}
  end

  def handle_event("submit_answer", %{"answer" => answer}, socket) do
    {answer, _} = Integer.parse(answer)

    EstimaFun.GameServer.submit_answer(
      via_tuple(socket.assigns.name),
      socket.assigns.user_id,
      answer
    )

    {:noreply, assign(socket, :current_answer, answer)}
  end

  def handle_event("continue", _params, %{assigns: %{game: game, user_id: user_id}} = socket) do
    if game.owner_id == user_id do
      EstimaFun.GameServer.continue(via_tuple(socket.assigns.name))
    end

    {:noreply, assign_game(socket)}
  end

  def handle_event("update_settings", %{"num_questions" => num_questions}, socket) do
    if socket.assigns.game.owner_id == socket.assigns.user_id do
      {num_questions, _} = Integer.parse(num_questions)
      EstimaFun.GameServer.update_settings(
        via_tuple(socket.assigns.name),
        %{num_questions: num_questions, owner_id: socket.assigns.user_id}
      )
    end

    {:noreply, assign_game(socket)}
  end

  def handle_info({:game_updated, game}, socket) do
    IO.puts("Received game update")  # Debug line
    {:noreply, assign(socket, game: game)}
  end

  def render(assigns) do
    assigns = assign(assigns,
      player_in_game?: player_in_game?(assigns.game, assigns.user_id),
      is_owner: assigns.game.owner_id == assigns.user_id,
      has_answered?: has_answered?(assigns.game, assigns.user_id),
      current_question: current_question(assigns.game)
    )

    ~H"""
    <div class="min-h-screen bg-gray-50 py-8">
      <div class="max-w-4xl mx-auto px-4">
        <div class="text-center mb-8">
          <h1 class="text-3xl font-bold text-gray-900">Estimation Game</h1>
        </div>

        <%!-- Si la partie n'a pas commencé, tout le monde peut la voir --%>
        <%= if @game.state == :waiting do %>
          <GameComponents.waiting_room
            game={@game}
            player_in_game={@player_in_game?}
            is_owner={@is_owner}
            default_name={@default_name}
          />
        <% end %>

        <%!-- Si la partie est en cours ou terminée et que le joueur en fait partie --%>
        <%= if @player_in_game? and @game.state != :waiting do %>
          <%= case @game.state do %>
            <% :playing -> %>
              <GameComponents.playing
                game={@game}
                current_question={@current_question}
                has_answered={@has_answered?}
              />

            <% :showing_results -> %>
              <GameComponents.showing_results
                game={@game}
                current_question={@current_question}
                is_owner={@is_owner}
              />

            <% :finished -> %>
              <GameComponents.game_over
                game={@game}
              />
          <% end %>
        <% end %>

        <%!-- Si la partie est en cours et que le joueur n'en fait pas partie --%>
        <%= if @game.state != :waiting and not @player_in_game? do %>
          <GameComponents.game_already_started />
        <% end %>
      </div>
    </div>
    """
  end

  # Helper functions

  defp current_question(game) do
    Enum.at(game.questions, game.current_question_index)
  end

  defp has_answered?(game, user_id) do
    Map.has_key?(game.current_answers, user_id)
  end

  defp player_in_game?(game, user_id) do
    Enum.any?(game.players, & &1.id == user_id)
  end

  defp generate_user_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16()
  end

  defp generate_game_name do
    ?a..?z
    |> Enum.take_random(8)
    |> List.to_string()
  end

  defp via_tuple(name) do
    {:via, Registry, {EstimaFun.GameRegistry, name}}
  end

  defp assign_game(socket, name) do
    socket
    |> assign(name: name)
    |> assign_game()
  end

  defp assign_game(%{assigns: %{name: name}} = socket) do
    game = GenServer.call(via_tuple(name), :get_game)
    assign(socket, game: game)
  end
end
