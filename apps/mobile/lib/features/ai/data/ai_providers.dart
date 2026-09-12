import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../domain/ai_models.dart';

final copilotProvider = FutureProvider.autoDispose<CopilotResult>((ref) async {
  final json = await ref.watch(apiClientProvider).getJson('/ai/copilot');
  return CopilotResult.fromJson(json);
});
