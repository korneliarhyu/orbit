export interface IntimacyState {
  score: number;
  level: number;
  totalExchanges: number;
  activeDays: number;
  xpToday: number;
  lastActiveDay: string | null;
}

export const initialIntimacy: IntimacyState = {
  score: 0,
  level: 1,
  totalExchanges: 0,
  activeDays: 0,
  xpToday: 0,
  lastActiveDay: null,
};

export function getIntimacyLevel(score: number): number {
  if (score >= 80) return 5;
  if (score >= 60) return 4;
  if (score >= 40) return 3;
  if (score >= 20) return 2;
  return 1;
}

export function calculateIntimacy(
  previous: IntimacyState,
  options: {
    meaningful: boolean;
    eligible: boolean;
    now: Date;
  },
): IntimacyState {
  // Spam and duplicate exchanges receive no XP.
  if (!options.eligible) return previous;

  const today = options.now.toISOString().slice(0, 10);
  const newDay = previous.lastActiveDay !== today;

  const earnedToday = newDay ? 0 : previous.xpToday;

  const baseXP = 1;
  const meaningfulXP = options.meaningful ? 1 : 0;
  const dailyBonus = newDay ? 2 : 0;

  // Maximum 10 intimacy XP per UTC day.
  const gained = Math.max(
    0,
    Math.min(
      10 - earnedToday,
      baseXP + meaningfulXP + dailyBonus,
    ),
  );

  const score = Math.min(100, previous.score + gained);

  return {
    score,
    level: getIntimacyLevel(score),
    totalExchanges: previous.totalExchanges + 1,
    activeDays: previous.activeDays + (newDay ? 1 : 0),
    xpToday: earnedToday + gained,
    lastActiveDay: today,
  };
}
