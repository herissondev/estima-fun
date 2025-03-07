defmodule EstimaFun.GameServer do
  @moduledoc """
  A turn-based estimation game using GenStateMachine with a 30-second limit for players to answer.
  """

  use GenStateMachine, callback_mode: [:state_functions, :state_enter]
  alias EstimaFun.Game
  require Logger

  @topic_prefix "game:"

  # -----------------------------------------------------------------
  # Public API
  # -----------------------------------------------------------------
  def start_link(options) do
    {name, options} = Keyword.pop(options, :name)
    {owner_id, _options} = Keyword.pop(options, :owner_id)

    game_name =
      case name do
        {:via, Registry, {_registry, raw_name}} -> raw_name
        _ -> name
      end

    init_data = %{
      game_name: game_name,
      owner_id: owner_id
    }

    GenStateMachine.start_link(__MODULE__, init_data, name: name)
  end

  def join_game(pid, player),
    do: GenStateMachine.call(pid, {:join_game, player})

  def start_game(pid),
    do: GenStateMachine.cast(pid, :start_game)

  def submit_answer(pid, player_id, answer),
    do: GenStateMachine.cast(pid, {:submit_answer, player_id, answer})

  def continue(pid),
    do: GenStateMachine.cast(pid, :continue)

  def get_game(pid),
    do: GenStateMachine.call(pid, :get_game)

  def update_settings(pid, settings),
    do: GenStateMachine.cast(pid, {:update_settings, settings})

  # -----------------------------------------------------------------
  # State Machine Callbacks
  # -----------------------------------------------------------------
  @impl true
  def init(init_data) do
    game = Game.new(Game.questions(), init_data.owner_id, init_data.game_name)
    {:ok, :waiting, game}
  end

  # -----------------------------------------------------------------
  # State: :waiting
  # -----------------------------------------------------------------
  @spec waiting(:cast | :enter | {:call, any()}, any(), any()) ::
          {:keep_state, any()}
          | {:keep_state_and_data, {:reply, any(), any()}}
          | {:keep_state, any(), {:reply, any(), :ok}}
          | {:next_state, :playing, %{:state => :playing, optional(any()) => any()}}
  def waiting(:enter, _old_state, game) do
    Logger.debug("Entering :waiting state for game #{game.id}")
    broadcast_update(game)
    {:keep_state, game}
  end

  def waiting({:call, from}, {:join_game, player}, game) do
    Logger.debug("Player #{player.id} joining game #{game.id}")
    new_game = Game.add_player(game, player)
    broadcast_update(new_game)
    {:keep_state, new_game, {:reply, from, :ok}}
  end

  def waiting({:call, from}, :get_game, game) do
    Logger.debug("Getting game state for #{game.id}")
    {:keep_state_and_data, {:reply, from, game}}
  end

  def waiting(:cast, {:update_settings, settings}, game) do
    Logger.debug("Updating settings for game #{game.id} by owner #{settings.owner_id}")
    if game.owner_id == settings.owner_id do
      new_game = Game.update_settings(game, settings)
      broadcast_update(new_game)
      {:keep_state, new_game}
    else
      {:keep_state, game}
    end
  end

  def waiting(:cast, :start_game, game) do
    Logger.debug("Starting game #{game.id}")
    new_game = Game.start_game(game)
    broadcast_update(new_game)
    {:next_state, :playing, new_game}
  end

  # -----------------------------------------------------------------
  # State: :playing
  # -----------------------------------------------------------------
  def playing(:enter, _old_state, game) do
    Logger.debug("Entering :playing state for game #{game.id}")
    broadcast_update(game)

    # Start a 30-second countdown and schedule timer updates every second
    Process.send_after(self(), :tick, 1000)
    game = Map.put(game, :time_remaining, 30)
    broadcast_update(game)

    {:keep_state, game, {:state_timeout, 30_000, :time_up}}
  end

  # Handle the tick message to update and broadcast remaining time
  def playing(:info, :tick, game) do
    if game.state == :playing && game.time_remaining > 0 do
      # Only continue ticking if we're still in playing state
      Process.send_after(self(), :tick, 1000)
      game = Map.put(game, :time_remaining, game.time_remaining - 1)
      broadcast_update(game)
      {:keep_state, game}
    else
      {:keep_state, game}
    end
  end

  # If 30 seconds pass and not all answers are in, we forcibly move to :showing_results
  def playing(:state_timeout, :time_up, game) do
    if game.state == :playing do
      # Only force finish if we're still in playing state
      Logger.debug("Time's up! Forcing round to end for game #{game.id}")
      new_game = Game.force_finish_round(game)
      new_game = Map.put(new_game, :time_remaining, 0)
      broadcast_update(new_game)
      {:next_state, :showing_results, new_game}
    else
      {:keep_state, game}
    end
  end

  def playing({:call, from}, :get_game, game) do
    Logger.debug("Getting game state for #{game.id}")
    {:keep_state_and_data, {:reply, from, game}}
  end

  def playing(:cast, {:submit_answer, player_id, answer}, game) do
    Logger.debug("Player #{player_id} submitting answer #{answer} for game #{game.id}")
    new_game = Game.submit_answer(game, player_id, answer)
    broadcast_update(new_game)

    case new_game.state do
      :showing_results ->
        # Cancel any remaining timer by not scheduling the next tick
        new_game = Map.put(new_game, :time_remaining, 0)
        broadcast_update(new_game)
        {:next_state, :showing_results, new_game}
      _ ->
        {:keep_state, new_game}
    end
  end

  # -----------------------------------------------------------------
  # State: :showing_results
  # -----------------------------------------------------------------
  def showing_results(:enter, _old_state, game) do
    Logger.debug("Entering :showing_results state for game #{game.id}")
    broadcast_update(game)
    {:keep_state, game}
  end

  def showing_results({:call, from}, :get_game, game) do
    Logger.debug("Getting game state for #{game.id}")
    {:keep_state_and_data, {:reply, from, game}}
  end

  # Ignorer les ticks restants du timer précédent
  def showing_results(:info, :tick, game) do
    {:keep_state, game}
  end

  def showing_results(:cast, :continue, game) do
    Logger.debug("Continuing to next round for game #{game.id}")
    new_game = Game.continue_to_next_round(game)
    broadcast_update(new_game)

    case new_game.state do
      :finished -> {:next_state, :finished, new_game}
      :playing -> {:next_state, :playing, new_game}
      _ -> {:keep_state, new_game}
    end
  end

  # -----------------------------------------------------------------
  # State: :finished
  # -----------------------------------------------------------------
  def finished(:enter, _old_state, game) do
    Logger.debug("Entering :finished state for game #{game.id}")
    Process.send_after(self(), :kill_game, 100_000)
    broadcast_update(game)
    {:keep_state, game}
  end

  def finished(:info, :kill_game, game) do
    Logger.debug("Killing game #{game.id}")
    {:stop, :normal, game}
  end

  def finished({:call, from}, :get_game, game) do
    Logger.debug("Getting game state for #{game.id}")
    {:keep_state_and_data, {:reply, from, game}}
  end

  def finished(:info, :tick, game) do
    {:keep_state, game}
  end

  # -----------------------------------------------------------------
  # Catch-all for any state
  # -----------------------------------------------------------------
  @impl true
  def handle_event(type, event, state, data) do
    Logger.debug("Unhandled event in game #{data.id}: #{inspect(event)} in state #{inspect(state)} (type: #{inspect(type)})")
    {:keep_state, data}
  end

  # -----------------------------------------------------------------
  # Helper Functions
  # -----------------------------------------------------------------
  defp broadcast_update(game) do
    topic = @topic_prefix <> game.id
    Phoenix.PubSub.broadcast(
      EstimaFun.PubSub,
      topic,
      {:game_updated, game}
    )
  end
end
