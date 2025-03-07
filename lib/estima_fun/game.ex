defmodule EstimaFun.Game do
  use GenServer
  alias EstimaFun.Game

  @topic_prefix "game:"

  defstruct [
    :id,
    :owner_id,
    # :waiting, :playing, :showing_results, :finished
    :state,
    # List of Player structs
    :players,
    # List of Question structs
    :questions,
    :current_question_index,
    # %{player_id => answer}
    :current_answers,
    :round_winners,
    :timer_ref,
    # Add round statistics
    :round_stats,
    settings: %{
      points_per_round: 10,
      scoring_strategy: :closest_wins,
      # 30 seconds in milliseconds
      results_display_time: 30_000,
      num_questions: 10  # Ajout du paramètre par défaut
    }
  ]

  @questions [
    %EstimaFun.Question{
      text: "Combien d'œufs sont consommés chaque jour dans le monde ?",
      correct_answer: 2_000_000_000
    },
    %EstimaFun.Question{
      text: "Combien de moustiques y a-t-il sur Terre en ce moment ?",
      correct_answer: 100_000_000_000_000
    },
    %EstimaFun.Question{
      text: "Combien de grains de sable peut-on trouver sur toutes les plages du monde ?",
      correct_answer: 7_500_000_000_000_000_000
    },
    %EstimaFun.Question{
      text: "Combien de pièces de Lego existent dans le monde ?",
      correct_answer: 700_000_000_000
    },
    %EstimaFun.Question{
      text: "Quel est le poids total combiné de tous les humains sur Terre ?",
      correct_answer: 350_000_000_000
    },
    %EstimaFun.Question{
      text: "Combien d'arbres sont coupés chaque seconde dans le monde ?",
      correct_answer: 27
    },
    %EstimaFun.Question{
      text: "Combien d'avions sont en vol à un instant donné ?",
      correct_answer: 9_000
    },
    %EstimaFun.Question{
      text: "Combien de kilomètres de routes existe-t-il à l'échelle mondiale ?",
      correct_answer: 64_285_000
    },
    %EstimaFun.Question{
      text: "Combien de satellites tournent autour de la Terre ?",
      correct_answer: 7_761
    },
    %EstimaFun.Question{
      text: "Combien de litres de bière sont consommés chaque année en Allemagne ?",
      correct_answer: 8_700_000_000
    },
    %EstimaFun.Question{
      text: "Combien de grains de riz sont mangés chaque jour dans le monde ?",
      correct_answer: 8_000_000_000_000
    },
    %EstimaFun.Question{
      text: "Combien de fois la hauteur de la Tour Eiffel faut-il pour atteindre la Lune ?",
      correct_answer: 332_000
    },
    %EstimaFun.Question{
      text: "Combien de cafés Starbucks existe-t-il dans le monde ?",
      correct_answer: 34_317
    },
    %EstimaFun.Question{
      text: "Combien de dents de requin sont perdues chaque année ?",
      correct_answer: 200_000_000
    },
    %EstimaFun.Question{
      text: "Combien de fois un humain moyen éternue-t-il dans sa vie ?",
      correct_answer: 150_000
    },
    %EstimaFun.Question{
      text: "Combien d'espèces d'insectes ont été recensées dans le monde ?",
      correct_answer: 900_000
    },
    %EstimaFun.Question{
      text: "Combien de litres d'eau l'océan Pacifique contient-il ?",
      correct_answer: 720_000_000_000_000_000_000
    },
    %EstimaFun.Question{
      text: "Combien de pizzas sont vendues chaque jour en Italie ?",
      correct_answer: 1_000_000
    },
    %EstimaFun.Question{
      text:
        "Combien de morceaux de musique sont écoutés chaque minute dans le monde sur Spotify ?",
      correct_answer: 750_000
    },
    %EstimaFun.Question{
      text: "Combien d'heures de vidéos sont regardées sur YouTube chaque jour ?",
      correct_answer: 1_000_000_000
    },
    %EstimaFun.Question{
      text: "Combien d'albums vinyles sont vendus dans le monde chaque année ?",
      correct_answer: 115_000_000
    },
    %EstimaFun.Question{
      text: "Combien de messages sont envoyés via WhatsApp chaque seconde ?",
      correct_answer: 69_000
    },
    %EstimaFun.Question{
      text: "Combien de bonbons M&M's sont produits chaque heure ?",
      correct_answer: 2_500_000
    },
    %EstimaFun.Question{
      text: "Combien de litres de ketchup sont consommés chaque année aux États-Unis ?",
      correct_answer: 650_000_000
    },
    %EstimaFun.Question{
      text: "Combien de coccinelles peuvent tenir sur la surface d'un ballon de football ?",
      correct_answer: 680
    },
    %EstimaFun.Question{
      text: "Combien de pièces de monnaie sont produites chaque année dans le monde ?",
      correct_answer: 40_000_000_000
    },
    %EstimaFun.Question{
      text: "Combien de livres sont empruntés dans les bibliothèques françaises chaque jour ?",
      correct_answer: 450_000
    },
    %EstimaFun.Question{
      text: "Combien de gouttes de pluie tombent pendant un orage moyen ?",
      correct_answer: 1_500_000_000
    },
    %EstimaFun.Question{
      text: "Combien de chiens naissent chaque jour dans le monde ?",
      correct_answer: 1_200_000
    },
    %EstimaFun.Question{
      text: "Combien de kilomètres un escargot parcourt-il au cours de sa vie ?",
      correct_answer: 115
    },
    %EstimaFun.Question{
      text: "Combien de grains de riz peut-on tenir dans une cuillère à soupe ?",
      correct_answer: 200
    },
    %EstimaFun.Question{
      text: "Combien de fois la Tour de Pise a-t-elle été frappée par la foudre ?",
      correct_answer: 37
    },
    %EstimaFun.Question{
      text: "Combien de fois un humain moyen cligne-t-il des yeux par jour ?",
      correct_answer: 28_800
    },
    %EstimaFun.Question{
      text: "Combien de kilomètres de cheveux une personne perd-elle au cours de sa vie ?",
      correct_answer: 725
    },
    %EstimaFun.Question{
      text:
        "Combien de secondes un cheveu peut-il flotter en apesanteur sur la Station spatiale internationale ?",
      correct_answer: 77
    },
    %EstimaFun.Question{
      text:
        "Combien d'arbres faut-il planter pour compenser un aller-retour Paris-New York en avion ?",
      correct_answer: 260
    },
    %EstimaFun.Question{
      text: "Combien de tonnes de glace sont vendues en France chaque année ?",
      correct_answer: 345_000
    },
    %EstimaFun.Question{
      text: "Combien de girafes peut-on faire tenir dans un Boeing 747 ?",
      correct_answer: 74
    },
    %EstimaFun.Question{
      text:
        "Combien de grains de pop-corn sont consommés lors d'une finale de la Coupe du Monde de football à l'échelle planétaire ?",
      correct_answer: 3_400_000_000
    },
    %EstimaFun.Question{
      text: "Combien de satellites peut-on lancer en un seul tir de fusée ?",
      correct_answer: 143
    }
  ]

  def start_link(options) do
    {name, options} = Keyword.pop(options, :name)
    {owner_id, options} = Keyword.pop(options, :owner_id)

    # Extract the game name from the via_tuple
    game_name =
      case name do
        {:via, Registry, {_registry, name}} -> name
        _ -> name
      end

    GenServer.start_link(__MODULE__, {owner_id, game_name}, name: name)
  end

  @impl true
  def init({owner_id, game_name}) do
    {:ok, Game.new(@questions, owner_id, game_name)}
  end

  @impl true
  def handle_call(:game, _from, game) do
    {:reply, game, game}
  end

  @impl true
  def handle_cast({:add_player, player}, game) do
    new_game = Game.add_player(game, player)
    broadcast_update(new_game)
    {:noreply, new_game}
  end

  @impl true
  def handle_cast(:start, game) do
    new_game = Game.start_game(game)
    broadcast_update(new_game)
    {:noreply, new_game}
  end

  @impl true
  def handle_cast({:submit_answer, {user, answer}}, game) do
    new_game = Game.submit_answer(game, user, answer)
    broadcast_update(new_game)
    {:noreply, new_game}
  end

  @impl true
  def handle_cast({:process_round}, game) do
    new_game = Game.process_round(game)
    broadcast_update(new_game)
    {:noreply, new_game}
  end

  @impl true
  def handle_cast(:continue, game) do
    new_game = Game.continue_to_next_round(game)
    broadcast_update(new_game)
    {:noreply, new_game}
  end

  @impl true
  def handle_cast({:update_settings, new_settings}, game) do
    new_game = update_settings(game, new_settings)
    broadcast_update(new_game)
    {:noreply, new_game}
  end

  def new(questions, owner_id, game_name, settings \\ %{}) do
    settings = Map.merge(%{
      points_per_round: 10,
      results_display_time: 30_000,
      num_questions: 10
    }, settings)

    %__MODULE__{
      id: game_name,
      state: :waiting,
      owner_id: owner_id,
      players: [],
      questions: Enum.take_random(questions, settings.num_questions),
      current_question_index: 0,
      current_answers: %{},
      round_winners: [],
      round_stats: %{},
      settings: settings
    }
  end

  def add_player(game = %{state: :waiting}, player) do
    %{game | players: [player | game.players]}
  end

  def add_player(game, _player), do: game

  def start_game(game = %{state: :waiting}) do
    %{game | state: :playing}
  end

  def submit_answer(game = %{state: :playing}, player_id, answer) do
    if player_exists?(game, player_id) do
      updated_game = %{game | current_answers: Map.put(game.current_answers, player_id, answer)}

      # Check if all players have answered after this submission
      if all_players_answered?(updated_game) do
        process_round(updated_game)
      else
        updated_game
      end
    else
      game
    end
  end

  def process_round(game) do
    if all_players_answered?(game) do
      game
      |> calculate_scores()
      # Add this step
      |> calculate_round_stats()
      |> set_round_winners()
      |> set_state(:showing_results)
    else
      game
    end
  end

  def continue_to_next_round(game = %{state: :showing_results}) do
    next_index = game.current_question_index + 1

    cond do
      next_index >= length(game.questions) ->
        %{game | state: :finished, current_answers: %{}, round_winners: []}

      true ->
        %{
          game
          | current_question_index: next_index,
            current_answers: %{},
            round_winners: [],
            state: :playing
        }
    end
  end

  def continue_to_next_round(game), do: game

  defp player_exists?(game, player_id) do
    Enum.any?(game.players, &(&1.id == player_id))
  end

  defp all_players_answered?(game) do
    submitted_ids = Map.keys(game.current_answers)
    Enum.all?(game.players, &(&1.id in submitted_ids))
  end

  defp calculate_scores(game) do
    current_question = Enum.at(game.questions, game.current_question_index)
    answers = game.current_answers
    scores = calculate_points(current_question.correct_answer, answers, game.settings)

    updated_players =
      Enum.map(game.players, fn player ->
        %{player | score: player.score + Map.get(scores, player.id, 0)}
      end)

    %{game | players: updated_players}
  end

  defp calculate_points(correct_answer, answers, settings) do
    diffs =
      Map.new(answers, fn {id, answer} ->
        {id, abs(answer - correct_answer)}
      end)

    closest_wins(diffs, settings.points_per_round)
  end

  defp closest_wins(diffs, points) do
    min_diff = Enum.min(Map.values(diffs))
    winners = Map.filter(diffs, fn {_id, diff} -> diff == min_diff end)
    points_per_winner = points / map_size(winners)

    Enum.reduce(winners, %{}, fn {id, _}, acc ->
      Map.put(acc, id, points_per_winner)
    end)
  end

  defp calculate_round_stats(game) do
    current_question = Enum.at(game.questions, game.current_question_index)
    answers = Map.values(game.current_answers)

    avg_answer = Enum.sum(answers) / length(answers)
    avg_error = abs(avg_answer - current_question.correct_answer)
    avg_error_percentage = avg_error / current_question.correct_answer * 100

    stats = %{
      average_answer: avg_answer,
      average_error: avg_error,
      average_error_percentage: avg_error_percentage,
      all_answers:
        Enum.sort_by(
          Enum.map(game.current_answers, fn {player_id, answer} ->
            player = Enum.find(game.players, &(&1.id == player_id))

            %{
              player: player,
              answer: answer,
              error: abs(answer - current_question.correct_answer),
              error_percentage:
                abs(answer - current_question.correct_answer) / current_question.correct_answer *
                  100
            }
          end),
          & &1.error
        )
    }

    %{game | round_stats: stats}
  end

  defp set_round_winners(game) do
    current_question = Enum.at(game.questions, game.current_question_index)

    winners =
      game.current_answers
      |> Enum.map(fn {player_id, answer} ->
        diff = abs(answer - current_question.correct_answer)
        {player_id, diff}
      end)
      |> Enum.sort_by(fn {_id, diff} -> diff end)
      # Top 3 closest answers
      |> Enum.take(3)
      |> Enum.map(fn {id, _diff} ->
        Enum.find(game.players, &(&1.id == id))
      end)

    %{game | round_winners: winners}
  end

  defp set_state(game, new_state), do: %{game | state: new_state}

  defp broadcast_update(game) do
    topic = @topic_prefix <> game.id
    # Debug line
    IO.puts("Broadcasting to topic: #{topic}")
    IO.inspect(game, label: "Game state")

    Phoenix.PubSub.broadcast(
      EstimaFun.PubSub,
      topic,
      {:game_updated, game}
    )
  end

  def update_settings(game = %{state: :waiting}, new_settings) do
    updated_settings = Map.merge(game.settings, new_settings)
    # Mélanger et prendre le bon nombre de questions
    selected_questions = Enum.take_random(@questions, updated_settings.num_questions)

    %{game |
      settings: updated_settings,
      questions: selected_questions
    }
  end

  def update_settings(game, _), do: game
end
