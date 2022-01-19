// import 'package:evac_app/components/demos/v0_0_2/demo_launcher.dart';
import 'package:evac_app/components/demos/elevation_tests/elevation_tests.dart';
import 'package:evac_app/components/demos/invite_code/invite_code_page.dart';
import 'package:flutter/material.dart';

import 'package:evac_app/components/demos/v0_0_3/rough_outline.dart';
import 'package:evac_app/styles.dart';

class App extends StatelessWidget {
  const App({Key? key, required this.title}) : super(key: key);
  final String title;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: title,
      theme: Styles.darkTheme,
      home: InviteCodePage(),
      // home: RoughOutline(),
      // home: ElevationTests(),
      // home: DemoLauncher(),
    );
  }
}
