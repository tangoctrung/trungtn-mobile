import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A scalable cover matching the gray folder chosen in the design preview.
class DefaultFolderCover extends StatelessWidget {
  const DefaultFolderCover({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: 'Ảnh thư mục mặc định',
    child: ColoredBox(
      color: const Color(0xFFF3F3F3),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = math.min(constraints.maxWidth * .54, 184.0);
          return Center(
            child: SizedBox(
              width: width,
              height: width * 116 / 140,
              child: const CustomPaint(painter: _FolderPainter()),
            ),
          );
        },
      ),
    ),
  );
}

class _FolderPainter extends CustomPainter {
  const _FolderPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 140, size.height / 116);
    final back = Path()
      ..moveTo(9, 27)
      ..quadraticBezierTo(9, 15, 21, 15)
      ..lineTo(48, 15)
      ..quadraticBezierTo(54, 15, 58, 21)
      ..lineTo(66, 29)
      ..lineTo(119, 29)
      ..quadraticBezierTo(132, 29, 132, 42)
      ..lineTo(132, 95)
      ..quadraticBezierTo(132, 107, 120, 107)
      ..lineTo(21, 107)
      ..quadraticBezierTo(9, 107, 9, 95)
      ..close();
    canvas.drawShadow(
      back.shift(const Offset(2, 3)),
      const Color(0x44000000),
      5,
      false,
    );
    canvas.drawPath(
      back.shift(const Offset(3, 3)),
      Paint()..color = const Color(0xFFA2A9B2),
    );
    canvas.drawPath(back, Paint()..color = const Color(0xFFB2B8C0));

    // Two paper edges give the folder some volume without adding detail at
    // small thumbnail sizes.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(24, 29, 92, 61),
        const Radius.circular(5),
      ),
      Paint()..color = const Color(0xFFDDE1E6),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(20, 33, 100, 61),
        const Radius.circular(5),
      ),
      Paint()..color = const Color(0xFFFAFAFB),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(31, 38, 73, 2),
        const Radius.circular(1),
      ),
      Paint()..color = const Color(0xFFD5DAE0),
    );

    // A taller front and a visible bottom/right edge make this version thicker
    // than the original preview while retaining the same soft gray palette.
    final front = Path()
      ..moveTo(8, 52)
      ..quadraticBezierTo(7, 41, 19, 41)
      ..lineTo(123, 41)
      ..quadraticBezierTo(135, 41, 134, 53)
      ..lineTo(129, 94)
      ..quadraticBezierTo(128, 105, 117, 105)
      ..lineTo(23, 105)
      ..quadraticBezierTo(13, 105, 12, 95)
      ..close();
    canvas.drawPath(
      front.shift(const Offset(2, 4)),
      Paint()..color = const Color(0xFFABB2BC),
    );
    canvas.drawPath(
      front,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE1E5EA), Color(0xFFC3C9D1)],
        ).createShader(const Rect.fromLTWH(8, 41, 126, 64)),
    );
    canvas.drawPath(
      front,
      Paint()
        ..color = const Color(0xFFB0B7C1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .8,
    );
    canvas.drawPath(
      Path()
        ..moveTo(20, 42)
        ..lineTo(122, 42),
      Paint()
        ..color = const Color(0xBBFFFFFF)
        ..strokeWidth = .8
        ..style = PaintingStyle.stroke,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _FolderPainter oldDelegate) => false;
}
