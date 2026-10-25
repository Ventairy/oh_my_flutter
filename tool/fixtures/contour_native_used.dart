// Reaches native contour tracing through the public widget.
import 'package:flutter/widgets.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

void main() {
  runApp(
    const Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: Contour(
          amount: 4,
          color: Color(0xffffffff),
          child: SizedBox(
            width: 300,
            height: 220,
            child: Text(
              'O',
              style: TextStyle(fontSize: 210, color: Color(0xff36ade9)),
            ),
          ),
        ),
      ),
    ),
  );
}
