defmodule EstimaFunWeb.GameComponents do
  use Phoenix.Component

  defp format_number(number) do
    number
    |> round()
    |> Integer.to_charlist()
    |> Enum.reverse()
    |> Enum.chunk_every(3)
    |> Enum.join(",")
    |> String.reverse()
  end

  def waiting_room(assigns) do
    ~H"""
    <div class="max-w-2xl mx-auto p-6 bg-white rounded-lg shadow-sm">
      <h2 class="text-2xl font-semibold text-gray-800 mb-6">Salle d'attente</h2>

      <div class="mb-8">
        <div class="flex items-center justify-between mb-4">
          <h3 class="text-lg font-medium text-gray-700">Joueurs</h3>
          <span class="text-sm text-gray-500">
            <%= length(@game.questions) %> questions sélectionnées
          </span>
        </div>
        <ul class="space-y-2">
          <%= for player <- @game.players do %>
            <li class="flex items-center space-x-2 text-gray-600">
              <span class="w-2 h-2 bg-green-400 rounded-full"></span>
              <span><%= player.name %></span>
              <%= if player.id == @game.owner_id do %>
                <span class="text-xs bg-blue-100 text-blue-800 px-2 py-0.5 rounded-full">Host</span>
              <% end %>
            </li>
          <% end %>
        </ul>
      </div>

      <div class="flex flex-col space-y-4">
        <%= if @is_owner do %>
          <div class="border-t border-gray-200 pt-4 mb-4">
            <form phx-submit="update_settings" class="space-y-4">
              <div>
                <label for="num_questions" class="block text-sm font-medium text-gray-700 mb-1">
                  Nombre de questions
                </label>
                <select
                  name="num_questions"
                  id="num_questions"
                  class="w-full px-4 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                >
                  <%= for n <- [5, 10, 15, 20, 25, 30] do %>
                    <option value={n} selected={@game.settings.num_questions == n}>
                      <%= n %> questions
                    </option>
                  <% end %>
                </select>
              </div>
              <button type="submit" class="w-full px-4 py-2 bg-gray-500 text-white rounded-md hover:bg-gray-600 transition">
                Mettre à jour les paramètres
              </button>
            </form>
          </div>
        <% end %>

        <%= if !@player_in_game do %>
          <form phx-submit="join_game" class="space-y-4">
            <div>
              <label for="player_name" class="block text-sm font-medium text-gray-700 mb-1">Votre nom</label>
              <input
                type="text"
                id="player_name"
                name="player_name"
                value={@default_name}
                class="w-full px-4 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                required
              >
            </div>
            <button type="submit" class="w-full px-4 py-2 bg-blue-500 text-white rounded-md hover:bg-blue-600 transition">
              Rejoindre la partie
            </button>
          </form>
        <% end %>

        <%= if @is_owner do %>
          <button phx-click="start_game" class="w-full px-4 py-2 bg-green-500 text-white rounded-md hover:bg-green-600 transition">
            Démarrer la partie
          </button>
        <% end %>
      </div>
    </div>
    """
  end

  def playing(assigns) do
    ~H"""
    <div class="max-w-2xl mx-auto p-6 bg-white rounded-lg shadow-sm">
      <div class="mb-6">
        <h2 class="text-2xl font-semibold text-gray-800">Question <%= @game.current_question_index + 1 %></h2>
        <p class="text-lg text-gray-600 mt-2"><%= @current_question.text %></p>
      </div>

      <%= if !@has_answered do %>
        <form phx-submit="submit_answer" class="space-y-4">
          <div>
            <input
              type="number"
              name="answer"
              placeholder="Your answer"
              class="w-full px-4 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
              required
            >
          </div>
          <button type="submit" class="w-full px-4 py-2 bg-blue-500 text-white rounded-md hover:bg-blue-600 transition">
            Submit Answer
          </button>
        </form>
      <% else %>
        <div class="text-center py-8">
          <p class="text-lg text-gray-600">Waiting for other players...</p>
          <div class="mt-4 animate-pulse">
            <div class="w-6 h-6 bg-blue-500 rounded-full mx-auto"></div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  def showing_results(assigns) do
    ~H"""
    <div class="max-w-2xl mx-auto p-6 bg-white rounded-lg shadow-sm">
      <h2 class="text-2xl font-semibold text-gray-800 mb-6">Results</h2>

      <div class="mb-8">
        <div class="grid grid-cols-2 gap-4 mb-6">
          <div class="p-4 bg-gray-50 rounded-lg">
            <h3 class="text-sm font-medium text-gray-500 mb-1">Correct Answer</h3>
            <p class="text-2xl font-semibold text-gray-900">
              <%= format_number(@current_question.correct_answer) %>
            </p>
          </div>
          <div class="p-4 bg-gray-50 rounded-lg">
            <h3 class="text-sm font-medium text-gray-500 mb-1">Group Average</h3>
            <p class="text-2xl font-semibold text-gray-900">
              <%= format_number(@game.round_stats.average_answer) %>
            </p>
            <p class="text-sm text-gray-500">
              Error: <%= Float.round(@game.round_stats.average_error_percentage, 1) %>%
            </p>
          </div>
        </div>

        <h3 class="text-lg font-medium text-gray-700 mb-4">All Answers</h3>
        <div class="space-y-3">
          <%= for {answer, index} <- Enum.with_index(@game.round_stats.all_answers) do %>
            <div class="flex items-center justify-between p-3 bg-gray-50 rounded-lg">
              <div class="flex items-center space-x-3">
                <%= case index do %>
                  <% 0 -> %><span class="text-2xl">🥇</span>
                  <% 1 -> %><span class="text-2xl">🥈</span>
                  <% 2 -> %><span class="text-2xl">🥉</span>
                  <% _ -> %><span class="w-8"></span>
                <% end %>
                <div>
                  <p class="font-medium"><%= answer.player.name %></p>
                  <p class="text-sm text-gray-500">Error: <%= Float.round(answer.error_percentage, 1) %>%</p>
                </div>
              </div>
              <span class="text-gray-600">
                <%= format_number(answer.answer) %>
              </span>
            </div>
          <% end %>
        </div>
      </div>

      <%= if @is_owner do %>
        <button phx-click="continue" class="w-full px-4 py-2 bg-blue-500 text-white rounded-md hover:bg-blue-600 transition">
          Continue to Next Question
        </button>
      <% end %>
    </div>
    """
  end

  def game_over(assigns) do
    ~H"""
    <div class="max-w-2xl mx-auto p-6 bg-white rounded-lg shadow-sm">
      <h2 class="text-2xl font-semibold text-gray-800 mb-6">Game Over!</h2>

      <div class="mb-8">
        <h3 class="text-lg font-medium text-gray-700 mb-4">Final Scores</h3>
        <div class="space-y-3">
          <%= for {player, index} <- Enum.with_index(Enum.sort_by(@game.players, & &1.score, :desc)) do %>
            <div class="flex items-center justify-between p-3 bg-gray-50 rounded-lg">
              <div class="flex items-center space-x-3">
                <%= if index == 0 do %>
                  <span class="text-2xl">👑</span>
                <% end %>
                <span class="font-medium"><%= player.name %></span>
              </div>
              <span class="text-gray-600">
                <%= player.score %> points
              </span>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  def game_already_started(assigns) do
    ~H"""
    <div class="max-w-2xl mx-auto p-6 bg-white rounded-lg shadow-sm text-center">
      <div class="mb-6">
        <h2 class="text-2xl font-semibold text-gray-800 mb-3">Partie en cours</h2>
        <p class="text-gray-600">Désolé, cette partie a déjà commencé.</p>
      </div>

      <div class="mt-8">
        <.link
          navigate="/"
          class="px-4 py-2 bg-blue-500 text-white rounded-md hover:bg-blue-600 transition"
        >
          Créer une nouvelle partie
        </.link>
      </div>
    </div>
    """
  end
end
