import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../services/api_service.dart';
import '../models/recommendation_model.dart';

// --- Events ---
abstract class RecommendationEvent extends Equatable {
  @override
  List<Object> get props => [];
}

class GetRecommendationEvent extends RecommendationEvent {
  final String text;
  final Map<String, dynamic>? userContext;
  GetRecommendationEvent(this.text, {this.userContext});
  @override
  List<Object> get props => [text, if (userContext != null) userContext!];
}

// --- States ---
abstract class RecommendationState extends Equatable {
  @override
  List<Object> get props => [];
}

class RecommendationInitial extends RecommendationState {}

class RecommendationLoading extends RecommendationState {}

class RecommendationLoaded extends RecommendationState {
  final RecommendationModel recommendation;
  RecommendationLoaded(this.recommendation);
  @override
  List<Object> get props => [recommendation];
}

class RecommendationError extends RecommendationState {
  final String message;
  RecommendationError(this.message);
  @override
  List<Object> get props => [message];
}

class AnalyzeAudioEvent extends RecommendationEvent {
  final String filePath;
  final Map<String, dynamic>? userContext;
  AnalyzeAudioEvent(this.filePath, {this.userContext});
  @override
  List<Object> get props => [filePath, if (userContext != null) userContext!];
}

// --- Bloc ---
class RecommendationBloc
    extends Bloc<RecommendationEvent, RecommendationState> {
  final ApiService apiService;

  RecommendationBloc({required this.apiService})
    : super(RecommendationInitial()) {
    on<GetRecommendationEvent>((event, emit) async {
      emit(RecommendationLoading());
      try {
        final recommendation = await apiService.getRecommendation(event.text, userContext: event.userContext);
        emit(RecommendationLoaded(recommendation));
      } catch (e) {
        emit(
          RecommendationError('تعذر الاتصال بالخادم، يرجى المحاولة لاحقاً.'),
        );
      }
    });

    on<AnalyzeAudioEvent>((event, emit) async {
      emit(RecommendationLoading());
      try {
        final recommendation = await apiService.analyzeAudio(event.filePath);
        emit(RecommendationLoaded(recommendation));
      } catch (e) {
        emit(
          RecommendationError(
            'فشل تحليل الصوت، تأكد من اتصالك بالإنترنت والمحاولة مجدداً.',
          ),
        );
      }
    });
  }
}
