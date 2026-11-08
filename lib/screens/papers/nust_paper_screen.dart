import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ustaad/providers/paper_provder.dart';
import 'package:ustaad/screens/papers/sim/net_sim_screen.dart';
import '../../models/paper_model.dart';
import 'paper_result_screen.dart';

class NustPaperScreen extends ConsumerStatefulWidget {
  final ExamType examType;
  final UserProgram? userProgram;
  const NustPaperScreen({
    super.key,
    required this.examType,
    this.userProgram,
  });

  @override
  ConsumerState<NustPaperScreen> createState() => _NustPaperScreenState();
}

class _NustPaperScreenState extends ConsumerState<NustPaperScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(paperSessionProvider.notifier)
          .startPaper(
            widget.examType,
            uid: FirebaseAuth.instance.currentUser?.uid ?? '',
            program: widget.userProgram,
          );
    });
  }

  void _showQuitDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1464),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'End the Paper?',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Poppins',
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Your progress will be lost and a new paper will load next time.',
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontFamily: 'Poppins',
            fontSize: 13,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: Color(0xFF4CAF50),
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text(
              'Quit',
              style: TextStyle(
                color: Color(0xFFFF6B6B),
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Submitting the whole paper, from wherever the student is in it.
  ///
  /// Asks first and says how many are blank. The real NET warns too, and an
  /// accidental submit on a 200-question paper cannot be undone.
  void _confirmSubmit(BuildContext context) {
    final session = ref.read(paperSessionProvider).valueOrNull;
    if (session == null) return;
    var unanswered = 0;
    for (final sec in session.sections) {
      for (final q in sec.questions) {
        if (session.answers[q.id]?.selectedIndex == null) unanswered++;
      }
    }
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text(
          'Finish your test?',
          style: TextStyle(
            color: Color(0xFF1F2937),
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          unanswered == 0
              ? 'You have answered every question. This cannot be undone.'
              : '$unanswered question(s) are still unanswered. '
                  'This cannot be undone.',
          style: const TextStyle(color: Color(0xFF4A5568), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Keep going'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              final result =
                  ref.read(paperSessionProvider.notifier).submitPaper();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => PaperResultScreen(result: result),
                ),
              );
            },
            child: const Text(
              'Finish',
              style: TextStyle(
                color: Color(0xFFC0392B),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(paperSessionProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _showQuitDialog(context);
      },
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0A0E2E), Color(0xFF1A1464), Color(0xFF2A1E80)],
            ),
          ),
          child: sessionAsync.when(
            loading: () => const _NustLoadingView(),
            error: (e, _) => _NustErrorView(error: e.toString()),
            data: (session) {
              if (session == null) return const _NustLoadingView();
              if (session.isSubmitted) return const SizedBox.shrink();
              return NetSimScreen(
                session: session,
                onSubmit: () => _confirmSubmit(context),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ─── Main exam body ───────────────────────────────────────────────────────────

class _NustLoadingView extends StatelessWidget {
  const _NustLoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: Color(0xFF4CAF50)),
          SizedBox(height: 16),
          Text(
            'Loading paper...',
            style: TextStyle(color: Colors.white54, fontFamily: 'Poppins'),
          ),
        ],
      ),
    );
  }
}

class _NustErrorView extends StatelessWidget {
  final String error;
  const _NustErrorView({required this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Something went wrong.\n$error',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white54, fontFamily: 'Poppins'),
        ),
      ),
    );
  }
}
