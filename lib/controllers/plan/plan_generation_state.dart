abstract class PlanGenerationState {}

class PlanGenerationInitial extends PlanGenerationState {}

class PlanGenerating extends PlanGenerationState {}

class PlanGenerationSuccess extends PlanGenerationState {}

class PlanGenerationError extends PlanGenerationState {
  final String message;
  PlanGenerationError(this.message);
}
