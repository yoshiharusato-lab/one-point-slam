class BracketGenerator
  # n 以上になる最小の2の累乗を返す(1回戦の枠数)。
  def self.bracket_slots(participant_count)
    return 2 if participant_count <= 2

    slots = 1
    slots <<= 1 while slots < participant_count
    slots
  end

  def self.bracket_size(participant_count)
    bracket_slots(participant_count)
  end

  # シード(不戦勝)になる人数。2の累乗ちょうどならゼロ。
  def self.bye_count(participant_count)
    return 0 if participant_count <= 1

    bracket_slots(participant_count) - participant_count
  end

  def self.round_match_counts(participant_count)
    return [] if participant_count < 2
    return [ 1 ] if participant_count == 2

    counts = []
    in_competition = participant_count
    initial_byes = bye_count(participant_count)

    playing = in_competition - initial_byes
    counts << playing / 2
    in_competition = counts.last + initial_byes

    while in_competition > 1
      round_byes = in_competition.odd? ? 1 : 0
      playing = in_competition - round_byes
      matches = playing / 2
      counts << matches
      in_competition = matches + round_byes
    end

    counts
  end

  def self.round_count(participant_count)
    round_match_counts(participant_count).size
  end

  def initialize(tournament)
    @tournament = tournament
  end

  def generate!
    raise ArgumentError, "参加者は2人以上必要です" if @tournament.participants.count < 2
    raise ArgumentError, "すでに開始済みです" unless @tournament.draft?

    participants = @tournament.participants.order(:created_at).to_a
    shuffled = participants.shuffle(random: Random.new(SecureRandom.random_number(2**31)))

    shuffled.each_with_index do |participant, index|
      participant.update!(seed: index + 1)
    end

    counts = self.class.round_match_counts(shuffled.size)
    initial_byes = self.class.bye_count(shuffled.size)

    Match.transaction do
      @tournament.matches.destroy_all

      counts.each_with_index do |match_count, round_index|
        round = round_index + 1
        (0...match_count).each do |position|
          @tournament.matches.create!(round: round, position: position, status: "pending")
        end
      end

      if initial_byes.positive?
        # round_match_counts は「シード(不戦勝)の人は1回戦を戦わず、そのまま2回戦の枠で待つ」
        # という前提でラウンドごとの試合数を割り出しているため、1回戦の試合記録数は
        # (参加者数 - シード数) / 2 しか無い。1回戦には実際に対戦するメンバーだけを割り当て、
        # シードの人は2回戦の枠に直接配置する。
        bye_participants = shuffled.last(initial_byes)
        round1_participants = shuffled.first(shuffled.size - initial_byes)

        first_round_matches = @tournament.matches.where(round: 1).order(:position).to_a
        round1_participants.each_slice(2).with_index do |(player1, player2), index|
          assign_first_round_match(first_round_matches[index], player1, player2)
        end

        next_round_matches = @tournament.matches.where(round: 2).order(:position).to_a
        BracketAdvancer.assign_byes_evenly(first_round_matches, next_round_matches, bye_participants)
      else
        first_round_matches = @tournament.matches.where(round: 1).order(:position)
        shuffled.each_slice(2).with_index do |(player1, player2), index|
          assign_first_round_match(first_round_matches[index], player1, player2)
        end
      end

      @tournament.update!(status: "active", started_at: Time.current)
    end
  end

  private

  def assign_first_round_match(match, player1, player2)
    if player1.present? && player2.present?
      match.update!(player1: player1, player2: player2, status: "ready")
    elsif player1.present?
      match.update!(player1: player1, status: "bye", winner: player1)
    elsif player2.present?
      match.update!(player2: player2, status: "bye", winner: player2)
    end
  end
end
