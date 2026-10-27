abstract class OnboardingState {}

class OnboardingInitial extends OnboardingState {}

class OnboardingSubmitting extends OnboardingState {}

class OnboardingSuccess extends OnboardingState {}

class OnboardingError extends OnboardingState {
  final String message;
  OnboardingError(this.message);
}
