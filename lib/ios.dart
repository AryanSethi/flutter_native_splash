part of flutter_native_splash_supported_platform;

// Image template
class _IosLaunchImageTemplate {
  final String fileName;
  final double divider;

  _IosLaunchImageTemplate({this.fileName, this.divider});
}

final List<_IosLaunchImageTemplate> _iOSSplashImages =
    <_IosLaunchImageTemplate>[
  _IosLaunchImageTemplate(fileName: 'LaunchImage.png', divider: 3),
  _IosLaunchImageTemplate(fileName: 'LaunchImage@2x.png', divider: 1.5),
  _IosLaunchImageTemplate(
      fileName: 'LaunchImage@3x.png', divider: 1), // original image must be @3x
];

final List<_IosLaunchImageTemplate> _iOSSplashImagesDark =
    <_IosLaunchImageTemplate>[
  _IosLaunchImageTemplate(fileName: 'LaunchImageDark.png', divider: 3),
  _IosLaunchImageTemplate(fileName: 'LaunchImageDark@2x.png', divider: 1.5),
  _IosLaunchImageTemplate(fileName: 'LaunchImageDark@3x.png', divider: 1),
  // original image must be @3x
];

/// Create iOS splash screen
void _createiOSSplash({
  String imagePath,
  String darkImagePath,
  String color,
  String darkColor,
  List<String> plistFiles,
  String iosContentMode,
  bool fullscreen,
}) async {
  if (imagePath.isNotEmpty) {
    await _applyImageiOS(imagePath: imagePath);
  } else {
    final splashImage = Image(1, 1);
    _iOSSplashImages.forEach((template) async {
      await File(_iOSAssetsLaunchImageFolder + template.fileName)
          .create(recursive: true)
          .then((File file) {
        file.writeAsBytesSync(encodePng(splashImage));
      });
    });
  }

  if (darkImagePath.isNotEmpty) {
    await _applyImageiOS(imagePath: darkImagePath, dark: true);
  } else {
    _iOSSplashImagesDark.forEach((template) {
      final file = File(_iOSAssetsLaunchImageFolder + template.fileName);
      if (file.existsSync()) file.deleteSync();
    });
  }

  await File(_iOSAssetsLaunchImageFolder + 'Contents.json')
      .create(recursive: true)
      .then((File file) {
    file.writeAsStringSync(
        darkImagePath.isNotEmpty ? _iOSContentsJsonDark : _iOSContentsJson);
  });

  await _applyLaunchScreenStoryboard(
      imagePath: imagePath, iosContentMode: iosContentMode);
  await _createBackgroundColor(colorString: color, darkColorString: darkColor);
  await _applyInfoPList(plistFiles: plistFiles, fullscreen: fullscreen);
}

/// Create splash screen images for original size, @2x and @3x
void _applyImageiOS({String imagePath, bool dark = false}) {
  print('[iOS] Creating ' + (dark ? 'dark mode ' : '') + 'splash images');
  if (!File(imagePath).existsSync()) {
    throw _NoImageFileFoundException('The file $imagePath was not found.');
  }

  final image = decodeImage(File(imagePath).readAsBytesSync());
  for (var template in dark ? _iOSSplashImagesDark : _iOSSplashImages) {
    _saveImageiOS(template: template, image: image);
  }
}

/// Saves splash screen image to the project
void _saveImageiOS({_IosLaunchImageTemplate template, Image image}) {
  var newFile = copyResize(
    image,
    width: image.width ~/ template.divider,
    height: image.height ~/ template.divider,
    interpolation: Interpolation.linear,
  );

  File(_iOSAssetsLaunchImageFolder + template.fileName)
      .create(recursive: true)
      .then((File file) {
    file.writeAsBytesSync(encodePng(newFile));
  });
}

/// Update LaunchScreen.storyboard adding width, height and color
Future _applyLaunchScreenStoryboard({String imagePath, String iosContentMode}) {
  final file = File(_iOSLaunchScreenStoryboardFile);

  if (file.existsSync()) {
    print('[iOS] Updating LaunchScreen.storyboard with width, and height');
    return _updateLaunchScreenStoryboard(
        imagePath: imagePath, iosContentMode: iosContentMode);
  } else {
    print('[iOS] No LaunchScreen.storyboard file found in your iOS project');
    print(
        '[iOS] Creating LaunchScreen.storyboard file and adding it to your iOS project');
    return _createLaunchScreenStoryboard(
        imagePath: imagePath, iosContentMode: iosContentMode);
  }
}

/// Updates LaunchScreen.storyboard adding splash image path
Future _updateLaunchScreenStoryboard(
    {String imagePath, String iosContentMode}) async {
  // Load the data
  final file = File(_iOSLaunchScreenStoryboardFile);
  final xmlDocument = XmlDocument.parse(file.readAsStringSync());
  final documentData = xmlDocument.getElement('document');

  // Find the view that contains the splash image
  final view =
      documentData.descendants.whereType<XmlElement>().firstWhere((element) {
    return (element.name.qualified == 'view' &&
        element.getAttribute('id') == 'Ze5-6b-2t3');
  });
  if (view == null) {
    throw _LaunchScreenStoryboardModified(
        'Default Flutter view Ze5-6b-2t3 not found. Did you modify your default LaunchScreen.storyboard file?');
  }

  // Find the splash imageView
  final subViews = view.getElement('subviews');
  final imageView = subViews.children.whereType<XmlElement>().firstWhere(
      (element) => (element.name.qualified == 'imageView' &&
          element.getAttribute('image') == 'LaunchImage'),
      orElse: () => throw _LaunchScreenStoryboardModified(
          "Not able to find 'LaunchImage' in LaunchScreen.storyboard. Image for splash screen not updated. Did you modify your default LaunchScreen.storyboard file?"));

  final backgroundView = subViews.children.whereType<XmlElement>().firstWhere(
      (element) => (element.name.qualified == 'imageView' &&
          element.getAttribute('image') == 'LaunchBackground'),
      orElse: () => null);
  // Update the fill property
  imageView.setAttribute('contentMode', iosContentMode);

  // Find the resources
  final resources = documentData.getElement('resources');
  var launchImageResource = resources.children
      .whereType<XmlElement>()
      .firstWhere(
          (element) => (element.name.qualified == 'image' &&
              element.getAttribute('name') == 'LaunchImage'),
          orElse: () => null);
  if (launchImageResource == null) {
    throw _LaunchScreenStoryboardModified(
        "Not able to find 'LaunchImage' in LaunchScreen.storyboard. Image for splash screen not updated. Did you modify your default LaunchScreen.storyboard file?");
  }
  final launchBackgroundResource = resources.children
      .whereType<XmlElement>()
      .firstWhere(
          (element) => (element.name.qualified == 'image' &&
              element.getAttribute('name') == 'LaunchBackground'),
          orElse: () => null);

  // If the color has not been set via background image, set it here:
  if (launchBackgroundResource == null) {
    resources.children.add(XmlDocument.parse(
            '<image name="LaunchBackground" width="1" height="1"/>')
        .rootElement
        .copy());
  }

  if (backgroundView == null) {
    subViews.children.insert(
        0, XmlDocument.parse(_iOSLaunchBackgroundSubview).rootElement.copy());
  }

  view.children.remove(view.getElement('constraints'));
  view.children.add(
      XmlDocument.parse(_iOSLaunchBackgroundConstraints).rootElement.copy());

  if (imagePath.isNotEmpty) {
    if (!File(imagePath).existsSync()) {
      throw _NoImageFileFoundException('The file $imagePath was not found.');
    }

    final image = decodeImage(File(imagePath).readAsBytesSync());
    launchImageResource.setAttribute('width', image.width.toString());
    launchImageResource.setAttribute('height', image.height.toString());
  }

  file.writeAsStringSync(xmlDocument.toXmlString(pretty: true, indent: '    '));
}

/// Creates LaunchScreen.storyboard with splash image path
Future _createLaunchScreenStoryboard(
    {String imagePath, String iosContentMode}) async {
  var file = await File(_iOSLaunchScreenStoryboardFile).create(recursive: true);
  await file.writeAsString(_iOSLaunchScreenStoryboardContent);
  return _updateLaunchScreenStoryboard(
      imagePath: imagePath, iosContentMode: iosContentMode);
}

Future<void> _createBackgroundColor(
    {String colorString, String darkColorString}) async {
  var background = Image(1, 1);
  var redChannel = int.parse(colorString.substring(0, 2), radix: 16);
  var greenChannel = int.parse(colorString.substring(2, 4), radix: 16);
  var blueChannel = int.parse(colorString.substring(4, 6), radix: 16);
  background.fill(
      0xFF000000 + (blueChannel << 16) + (greenChannel << 8) + redChannel);
  await File(_iOSAssetsLaunchImageBackgroundFolder + 'background.png')
      .create(recursive: true)
      .then((File file) => file.writeAsBytesSync(encodePng(background)));

  if (darkColorString.isNotEmpty) {
    redChannel = int.parse(darkColorString.substring(0, 2), radix: 16);
    greenChannel = int.parse(darkColorString.substring(2, 4), radix: 16);
    blueChannel = int.parse(darkColorString.substring(4, 6), radix: 16);
    background.fill(
        0xFF000000 + (blueChannel << 16) + (greenChannel << 8) + redChannel);
    await File(_iOSAssetsLaunchImageBackgroundFolder + 'darkbackground.png')
        .create(recursive: true)
        .then((File file) => file.writeAsBytesSync(encodePng(background)));
  } else {
    final file =
        File(_iOSAssetsLaunchImageBackgroundFolder + 'darkbackground.png');
    if (file.existsSync()) file.deleteSync();
  }

  return File(_iOSAssetsLaunchImageBackgroundFolder + 'Contents.json')
      .create(recursive: true)
      .then((File file) {
    file.writeAsStringSync(darkColorString.isNotEmpty
        ? _iOSLaunchBackgroundDarkJson
        : _iOSLaunchBackgroundJson);
  });
}

/// Update Info.plist for status bar behaviour (hidden/visible)
Future _applyInfoPList({List<String> plistFiles, bool fullscreen}) async {
  if (plistFiles == null) {
    plistFiles = [];
    plistFiles.add(_iOSInfoPlistFile);
  }

  plistFiles.forEach((plistFile) async {
    if (!await File(plistFile).exists()) {
      throw _CantFindInfoPlistFile(
          'File $plistFile not found.  If you renamed the file, make sure to '
          'specify it in the info_plist_files section of your '
          'flutter_native_splash configuration.');
    }

    print('[iOS] Updating $plistFile for status bar hidden/visible');
    await _updateInfoPlistFile(plistFile: plistFile, fullscreen: fullscreen);
  });
}

/// Update Infop.list with status bar hidden directive
Future _updateInfoPlistFile({String plistFile, bool fullscreen}) async {
  // Load the data
  final file = File(plistFile);
  final xmlDocument = XmlDocument.parse(file.readAsStringSync());
  final dict = xmlDocument.getElement('plist').getElement('dict');

  final uIStatusBarHidden =
      dict.children.whereType<XmlElement>().firstWhere((element) {
    return (element.text == 'UIStatusBarHidden');
  }, orElse: () {
    final builder = XmlBuilder();
    builder.element('key', nest: () {
      builder.text('UIStatusBarHidden');
    });
    dict.children.add(builder.buildFragment());
    dict.children.add(XmlElement(XmlName(fullscreen.toString())));
    return null;
  });

  if (uIStatusBarHidden != null) {
    var index = dict.children.indexOf(uIStatusBarHidden);
    var uIStatusBarHiddenValue = dict.children[index + 1].following
        .firstWhere((element) => element.nodeType == XmlNodeType.ELEMENT);
    uIStatusBarHiddenValue.replace(XmlElement(XmlName(fullscreen.toString())));
  }

  if (fullscreen) {
    final uIViewControllerBasedStatusBarAppearance =
        dict.children.whereType<XmlElement>().firstWhere((element) {
      return (element.text == 'UIViewControllerBasedStatusBarAppearance');
    }, orElse: () {
      final builder = XmlBuilder();
      builder.element('key', nest: () {
        builder.text('UIViewControllerBasedStatusBarAppearance');
      });
      dict.children.add(builder.buildFragment());
      dict.children.add(XmlElement(XmlName((!fullscreen).toString())));
      return null;
    });

    if (uIViewControllerBasedStatusBarAppearance != null) {
      var index =
          dict.children.indexOf(uIViewControllerBasedStatusBarAppearance);

      var uIViewControllerBasedStatusBarAppearanceValue = dict
          .children[index + 1].following
          .firstWhere((element) => element.nodeType == XmlNodeType.ELEMENT);
      uIViewControllerBasedStatusBarAppearanceValue
          .replace(XmlElement(XmlName('false')));
    }
  }

  file.writeAsStringSync(xmlDocument.toXmlString(pretty: true, indent: '	'));
}
