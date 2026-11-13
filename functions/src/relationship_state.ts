export type BoundarySignal =
  | "none"
  | "warning"
  | "repeated_violation";

export interface BoundaryState {
  warnings: number;
  calmExchanges: number;
}

export const initialBoundaryState: BoundaryState = {
  warnings: 0,
  calmExchanges: 0,
};

export function isActiveRelationship(status: unknown): boolean {
  return status == null || status === "active";
}

export function evaluateBoundary(
  previous: Partial<BoundaryState> | null | undefined,
  signal: BoundarySignal,
) {
  const warnings = Math.max(
    0,
    Math.min(5, Math.floor(previous?.warnings ?? 0)),
  );

  const calm = Math.max(
    0,
    Math.min(3, Math.floor(previous?.calmExchanges ?? 0)),
  );

  if (signal === "none") {
    const calmExchanges = calm + 1;

    return {
      state: {
        warnings: calmExchanges >= 3
            ? Math.max(0, warnings - 1)
            : warnings,
        calmExchanges: calmExchanges >= 3 ? 0 : calmExchanges,
      },
      shouldUnmatch: false,
    };
  }

  if (signal === "warning") {
    return {
      state: {
        warnings: Math.min(5, warnings + 1),
        calmExchanges: 0,
      },
      shouldUnmatch: false,
    };
  }

  return {
    state: {
      warnings: Math.min(5, warnings + 1),
      calmExchanges: 0,
    },
    shouldUnmatch: warnings >= 2,
  };
}