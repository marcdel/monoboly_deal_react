defmodule MonobolyDeal.Game do
  defstruct [
    :name,
    :players,
    :hands,
    :discard_pile,
    :deck,
    :started,
    :current_turn
  ]

  alias MonobolyDeal.Deck
  alias MonobolyDeal.Game
  alias MonobolyDeal.Game.Turn

  def new(name, player) do
    %Game{
      name: name,
      players: [player],
      hands: %{player.name => []},
      discard_pile: [],
      deck: Deck.new() |> Deck.shuffle(),
      started: false,
      current_turn: Turn.new(nil)
    }
  end

  def join(%{started: true} = game, player) do
    case playing?(game, player) do
      false -> {:error, %{error: :game_started, message: "Oops! This game has already started."}}
      true -> {:ok, game}
    end
  end

  def join(game, player) do
    case playing?(game, player) do
      false ->
        {:ok,
         %{game | players: game.players ++ [player], hands: Map.put(game.hands, player.name, [])}}

      true ->
        {:ok, game}
    end
  end

  def draw_cards(%{current_turn: %{player: turn_player}} = game, current_player)
      when turn_player != current_player do
    game
  end

  def draw_cards(%{current_turn: %{drawn_cards: [_, _]}} = game, _) do
    game
  end

  def draw_cards(game, player) do
    {cards, updated_deck} = Enum.split(game.deck, 2)
    player_hand = get_hand(game, player)
    updated_hands = %{game.hands | player.name => player_hand ++ cards}

    %{
      game
      | hands: updated_hands,
        deck: updated_deck,
        current_turn: %{game.current_turn | drawn_cards: cards}
    }
  end

  def choose_card(%{current_turn: %{drawn_cards: []}}, _, _), do: {:error, :draw_cards}

  def choose_card(%{current_turn: %{player: turn_player}}, current_player, _)
      when turn_player != current_player do
    {:error, :not_your_turn}
  end

  def choose_card(game, player, card_id) do
    card = Game.find_card(game, player, card_id)
    {:ok, %{game | current_turn: %{game.current_turn | chosen_card: card}}}
  end

  def place_card_bank(%{current_turn: %{chosen_card: nil}}, _) do
    {:error, :choose_card}
  end

  def place_card_bank(%{current_turn: %{player: p1}}, p2) when p1 != p2 do
    {:error, :not_your_turn}
  end

  def place_card_bank(%{current_turn: %{player: player}} = game, player) do
    %{name: name} = player
    card = game.current_turn.chosen_card

    updated_players =
      Enum.map(game.players, fn
        %{name: ^name} = found_player -> add_to_bank(found_player, card)
        other_player -> other_player
      end)

    player_hand = get_hand(game, player)

    updated_hands = %{
      game.hands
      | player.name => Enum.reject(player_hand, fn c -> c.id == card.id end)
    }

    {:ok,
     %{
       game
       | players: updated_players,
         hands: updated_hands,
         current_turn: %{game.current_turn | chosen_card: nil}
     }}
  end

  def find_card(game, player, card_id) do
    hand = Game.get_hand(game, player)
    Enum.find(hand, fn card -> card.id == card_id end)
  end

  def deal(game) do
    game =
      Enum.reduce(
        game.players,
        game,
        fn player, game ->
          {hand, updated_deck} = Enum.split(game.deck, 5)
          updated_hands = %{game.hands | player.name => hand}

          %{game | hands: updated_hands, deck: updated_deck, started: true}
        end
      )

    %{game | started: true, current_turn: Turn.new(Enum.random(game.players))}
  end

  def game_state(game) do
    %{
      game_name: game.name,
      players: game.players,
      started: game.started,
      current_turn: game.current_turn
    }
  end

  def player_state(game, player) do
    game
    |> find_player(player)
    |> build_player_state(game)
  end

  def get_hand(game, player) do
    Map.fetch!(game.hands, player.name)
  end

  def find_player(game, player) do
    Enum.find(game.players, fn p -> p.name == player.name end)
  end

  defp add_to_bank(%{bank: nil} = player, card) do
    %{player | bank: [card]}
  end

  defp add_to_bank(player, card) do
    %{player | bank: player.bank ++ [card]}
  end

  defp playing?(game, player) do
    Enum.any?(game.players, fn p -> p.name == player.name end)
  end

  defp build_player_state(nil, _), do: nil

  defp build_player_state(player, %{current_turn: %{player: nil}} = game) do
    %{
      name: player.name,
      bank: player.bank,
      hand: get_hand(game, player),
      my_turn: false
    }
  end

  defp build_player_state(player, game) do
    %{
      name: player.name,
      bank: player.bank,
      hand: get_hand(game, player),
      my_turn: game.current_turn.player == player
    }
  end
end
