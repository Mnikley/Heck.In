import 'package:flutter/material.dart';
import 'package:hedge_profiler_flutter/snackbar.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:url_launcher/url_launcher.dart';

void doNothing() {}

int determineRequiredColumnsFromScreenWidth(var mediaQueryData) {
  final screenWidth = mediaQueryData.size.width;
  int columns = 1;
  if (screenWidth > 960) {
    columns = 5;
  } else if (screenWidth > 840) {
    columns = 4;
  } else if (screenWidth > 720) {
    columns = 3;
  } else if (screenWidth > 600) {
    columns = 2;
  }
  return columns;
}

Padding paddedWidget(Widget widget,
    {double horizontalPadding = 4.0, double verticalPadding = 4.0}) {
  // TODO: refactor all Padding( calls
  return Padding(
      padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding, vertical: verticalPadding),
      child: widget);
}

Column widgetWithBottomPadding(Widget widget) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      widget,
      const SizedBox(height: 16)
    ],
  );
}

Center createHeader(String headerText, {double fontSize = 24}) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        headerText,
        style: TextStyle(fontSize: fontSize),
      ),
    ),
  );
}


class ConfirmationDialog extends StatelessWidget {
  final String message;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const ConfirmationDialog({
    Key? key,
    required this.message,
    required this.onConfirm,
    required this.onCancel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Confirm Action'),
      content: Text(message),
      actions: <Widget>[
        TextButton(
          onPressed: onCancel,
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: onConfirm,
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}

class ToolTipDialog extends StatelessWidget {
  final String header;
  final String message;
  final String navigateToMapButtonText;
  final VoidCallback onNavigateToMap;
  final String closeButtonText;
  final VoidCallback onClose;
  final bool createGoToMapButton;

  const ToolTipDialog(
      {Key? key,
      required this.header,
      required this.message,
      required this.navigateToMapButtonText,
      required this.onNavigateToMap,
      required this.closeButtonText,
      required this.onClose,
      required this.createGoToMapButton})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    List<Widget> actionsList = [];

    if (createGoToMapButton) {
      actionsList.add(
        TextButton(
            onPressed: onNavigateToMap, child: Text(navigateToMapButtonText)),
      );
    }

    actionsList.add(TextButton(
      onPressed: onClose,
      child: Text(closeButtonText),
    ));

    return AlertDialog(
      title: Text(header),
      // content: Text(message),
      content: Linkify(
        onOpen: (link) async {
          if (!await launchUrl(Uri.parse(link.url))) {
            showSnackbar(context, "Could not launch ${link.url}",
                success: false);
          }
        },
        text: message,
        textAlign: TextAlign.justify,
      ),
      actions: actionsList,
    );
  }
}

class LocaleMap {
  List<Map<String, dynamic>> formFields = [];
  List<Map<String, dynamic>> sections = [];

  void initialize(
      List<Map<String, dynamic>> formFields,
      List<Map<String, dynamic>> sections) {
    this.formFields = formFields;
    this.sections = sections;
  }

  Map<String, String> getLocaleToOriginal(String locale) {
    Map<String, String> map = {};

    if (locale.isEmpty) {
      return map;
    }

    for (Map<String, dynamic> field in formFields) {
      map[field["label$locale"]] = field["label"];
      if (field.containsKey("values")) {
        for (int i = 0; i < field["values"].length; i++) {
          if (field["values"][i] == "") {
            continue;
          }
          map[field["values$locale"][i]] = field["values"][i];
        }
      }
    }

    for (Map<String, dynamic> sec in sections) {
      map[sec["label$locale"]] = sec["label"].toString();
    }

    return map;
  }

  Map<String, String> getOriginalToLocale(String locale) {
    Map<String, String> map = {};

    if (locale.isEmpty) {
      return map;
    }

    for (Map<String, dynamic> field in formFields) {
      map[field["label"]] = field["label$locale"];
      if (field.containsKey("values")) {
        for (int i = 0; i < field["values"].length; i++) {
          if (field["values"][i] == "") {
            continue;
          }
          map[field["values"][i]] = field["values$locale"][i];
        }
      }
    }

    for (Map<String, dynamic> sec in sections) {
      map[sec["label"].toString()] = sec["label$locale"];
    }

    return map;
  }
}

