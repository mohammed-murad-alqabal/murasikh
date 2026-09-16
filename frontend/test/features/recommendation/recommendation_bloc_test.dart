import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:murassikh_app/features/recommendation/bloc/recommendation_bloc.dart';
import 'package:murassikh_app/features/recommendation/models/recommendation_model.dart';
import 'package:murassikh_app/services/api_service.dart';

class MockApiService extends Mock implements ApiService {}

void main() {
  late RecommendationBloc bloc;
  late MockApiService mockApiService;

  setUp(() {
    mockApiService = MockApiService();
    bloc = RecommendationBloc(apiService: mockApiService);
  });

  tearDown(() {
    bloc.close();
  });

  group('RecommendationBloc', () {
    final testModel = RecommendationModel(
      emotion: 'حزن',
      confidence: 0.8,
      message: 'لا تحزن',
      source: 'القرآن',
      tafsir: 'تفسير',
      tier: 'full',
    );

    test('initial state is RecommendationInitial', () {
      expect(bloc.state, isA<RecommendationInitial>());
    });

    blocTest<RecommendationBloc, RecommendationState>(
      'emits [RecommendationLoading, RecommendationLoaded] on success',
      build: () {
        when(() => mockApiService.getRecommendation('test text'))
            .thenAnswer((_) async => testModel);
        return bloc;
      },
      act: (bloc) => bloc.add(GetRecommendationEvent('test text')),
      expect: () => [isA<RecommendationLoading>(), isA<RecommendationLoaded>()],
      verify: (_) {
        verify(() => mockApiService.getRecommendation('test text')).called(1);
      },
    );

    blocTest<RecommendationBloc, RecommendationState>(
      'emits [RecommendationLoading, RecommendationError] on failure',
      build: () {
        when(() => mockApiService.getRecommendation('test text'))
            .thenThrow(Exception('Network Error'));
        return bloc;
      },
      act: (bloc) => bloc.add(GetRecommendationEvent('test text')),
      expect: () => [isA<RecommendationLoading>(), isA<RecommendationError>()],
    );
  });
}
