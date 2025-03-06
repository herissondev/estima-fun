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
      <h2 class="text-2xl font-semibold text-gray-800 mb-6">Waiting Room</h2>

      <div class="mb-8">
        <h3 class="text-lg font-medium text-gray-700 mb-3">Players</h3>
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
        <%= if !@player_in_game do %>
          <form phx-submit="join_game" class="space-y-4">
            <div>
              <label for="player_name" class="block text-sm font-medium text-gray-700 mb-1">Your Name</label>
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
              Join Game
            </button>
          </form>
        <% end %>

        <%= if @is_owner do %>
          <button phx-click="start_game" class="w-full px-4 py-2 bg-green-500 text-white rounded-md hover:bg-green-600 transition">
            Start Game
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
end
