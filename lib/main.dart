import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:gal/gal.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mlkit_subject_segmentation/google_mlkit_subject_segmentation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:text_3d/text_3d.dart';

import 'web_download.dart' if (dart.library.io) 'dummy_download.dart';

void main() {
  runApp(const PosterApp());
}

class PosterApp extends StatelessWidget {
  const PosterApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: PosterScreen(),
    );
  }
}

// 1. Model Quản lý Chữ
class PosterTextItem {
  String text;
  Offset position;
  double fontSize;
  Color textColor;
  double opacity;
  double rotation;
  String fontFamily;
  bool is3D;
  ThreeDStyle threeDStyle;
  double depth;

  PosterTextItem({
    required this.text,
    required this.position,
    this.fontSize = 22.0,
    this.textColor = Colors.black,
    this.opacity = 1.0,
    this.rotation = 0.0,
    this.fontFamily = 'Dancing Script',
    this.is3D = false,
    this.threeDStyle = ThreeDStyle.raised,
    this.depth = 8.0,
  });
}

// 2. Model Quản lý Hình Ảnh Ghép
class PosterImageIcon {
  Uint8List imageBytes;
  Offset position;
  double width;
  double height;
  double opacity;
  double rotation;
  BlendMode blendMode;
  bool softEdges;
  bool isOval;

  PosterImageIcon({
    required this.imageBytes,
    required this.position,
    this.width = 120.0,
    this.height = 120.0,
    this.opacity = 1.0,
    this.rotation = 0.0,
    this.blendMode = BlendMode.dst,
    this.softEdges = false,
    this.isOval = false,
  });
}

class PosterScreen extends StatefulWidget {
  const PosterScreen({Key? key}) : super(key: key);

  @override
  _PosterScreenState createState() => _PosterScreenState();
}

class _PosterScreenState extends State<PosterScreen> {
  final GlobalKey _globalKey = GlobalKey();
  final TextEditingController _textController = TextEditingController();

  // Biến quản lý tạo chữ mới
  Color _newTextColor = Colors.black;
  double _newFontSize = 22.0;
  String _newFontFamily = 'Dancing Script';
  bool _newIs3D = false;
  ThreeDStyle _newThreeDStyle = ThreeDStyle.raised;

  // Biến quản lý vị trí ảnh ghép đang được chọn
  int? _selectedImageIndex;

  // Biến kích thước & Nền Poster
  double _posterWidth = 350.0;
  double _posterHeight = 500.0;
  Color _backgroundColor = Colors.amber[300]!;
  Uint8List? _backgroundImageBytes;

  final List<String> _fontList = [
    'Dancing Script',
    'Caveat',
    'Pacifico',
    'Great Vibes',
    'Alex Brush',
    'Satisfy',
    'Sacramento',
    'Montserrat',
    'Playfair Display',
    'Roboto',
    'Open Sans',
    'Arial',
    'Times New Roman',
  ];

  final ImagePicker _picker = ImagePicker();
  bool _isRemovingBg = false;

  final List<PosterTextItem> _textItems = [
    PosterTextItem(
      text: "Poster của tôi",
      position: const Offset(80, 150),
      fontFamily: 'Dancing Script',
      is3D: true,
      threeDStyle: ThreeDStyle.raised,
    ),
  ];
  final List<PosterImageIcon> _imageItems = [];

  final Map<String, BlendMode> _blendModesMap = {
    'Bình thường (Normal)': BlendMode.dst,
    'Hòa trộn tối (Multiply)': BlendMode.multiply,
    'Hòa trộn sáng (Screen)': BlendMode.screen,
    'Tương phản (Overlay)': BlendMode.overlay,
    'Ánh sáng mềm (Soft Light)': BlendMode.softLight,
    'Ánh sáng mạnh (Hard Light)': BlendMode.hardLight,
    'Chỉ lấy nét tối (Darken)': BlendMode.darken,
    'Chỉ lấy nét sáng (Lighten)': BlendMode.lighten,
    'Làm mờ/Trộn (Difference)': BlendMode.difference,
  };

  TextStyle _getFontFamilyStyle(String font, double size, Color color) {
    if (font == 'Arial' || font == 'Times New Roman') {
      return TextStyle(
        fontFamily: font,
        fontSize: size,
        color: color,
        fontWeight: FontWeight.bold,
      );
    }
    try {
      return GoogleFonts.getFont(
        font,
        fontSize: size,
        color: color,
        fontWeight: FontWeight.bold,
      );
    } catch (e) {
      return GoogleFonts.roboto(
        fontSize: size,
        color: color,
        fontWeight: FontWeight.bold,
      );
    }
  }

  Widget _buildTextWidget(PosterTextItem item) {
    TextStyle style = _getFontFamilyStyle(
      item.fontFamily,
      item.fontSize,
      item.textColor,
    );

    if (!item.is3D) {
      return Text(item.text, style: style);
    }

    return ThreeDText(
      text: item.text,
      textStyle: style,
      depth: item.depth,
      style: item.threeDStyle,
      perspectiveDepth: 30,
    );
  }

  void _addNewText() {
    if (_textController.text.trim().isEmpty) return;
    setState(() {
      _textItems.add(
        PosterTextItem(
          text: _textController.text,
          position: const Offset(50, 50),
          fontSize: _newFontSize,
          textColor: _newTextColor,
          fontFamily: _newFontFamily,
          is3D: _newIs3D,
          threeDStyle: _newThreeDStyle,
        ),
      );
      _textController.clear();
    });
  }

  // --- BỔ SUNG: CHỌN MÀU NỀN VÀ KÍCH THƯỚC POSTER ---
  void _openPosterSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Cấu hình Khung Poster",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const Divider(),
                    const SizedBox(height: 10),
                    // 1. Màu nền
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Màu nền Poster:", style: TextStyle(fontWeight: FontWeight.bold)),
                        GestureDetector(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  title: const Text('Chọn màu nền'),
                                  content: SingleChildScrollView(
                                    child: ColorPicker(
                                      pickerColor: _backgroundColor,
                                      onColorChanged: (color) {
                                        setState(() => _backgroundColor = color);
                                        setModalState(() {});
                                      },
                                      pickerAreaHeightPercent: 0.7,
                                      enableAlpha: false,
                                    ),
                                  ),
                                  actions: [
                                    ElevatedButton(
                                      child: const Text('Đồng ý'),
                                      onPressed: () => Navigator.of(context).pop(),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                          child: Container(
                            width: 100,
                            height: 35,
                            decoration: BoxDecoration(
                              color: _backgroundColor,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey),
                            ),
                            child: const Center(
                              child: Text(
                                "Đổi màu",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  shadows: [Shadow(blurRadius: 3, color: Colors.black)],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_backgroundImageBytes != null) ...[
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () {
                          setState(() => _backgroundImageBytes = null);
                          setModalState(() {});
                        },
                        icon: const Icon(Icons.delete_forever, color: Colors.red),
                        label: const Text("Xóa ảnh nền (Dùng màu đơn sắc)", style: TextStyle(color: Colors.red)),
                      ),
                    ],
                    const SizedBox(height: 20),
                    // 2. Kích thước Poster
                    Text("Chiều rộng Poster: ${_posterWidth.round()} px"),
                    Slider(
                      value: _posterWidth,
                      min: 250.0,
                      max: 450.0,
                      divisions: 20,
                      onChanged: (val) {
                        setState(() => _posterWidth = val);
                        setModalState(() {});
                      },
                    ),
                    Text("Chiều cao Poster: ${_posterHeight.round()} px"),
                    Slider(
                      value: _posterHeight,
                      min: 300.0,
                      max: 700.0,
                      divisions: 40,
                      onChanged: (val) {
                        setState(() => _posterHeight = val);
                        setModalState(() {});
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Xử lý tách nền Offline ML Kit
  Future<Uint8List?> _removeBackgroundOffline(Uint8List imageBytes) async {
    if (kIsWeb) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Tính năng tách nền Offline chỉ hỗ trợ trên thiết bị Mobile (Android/iOS)!"),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return null;
    }

    SubjectSegmenter? segmenter;
    try {
      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}/temp_${DateTime.now().millisecondsSinceEpoch}.png');
      await tempFile.writeAsBytes(imageBytes);

      final options = SubjectSegmenterOptions(
        enableForegroundBitmap: true,
        enableForegroundConfidenceMask: true,
        enableMultipleSubjects: SubjectResultOptions(
          enableConfidenceMask: false,
          enableSubjectBitmap: false,
        ),
      );

      segmenter = SubjectSegmenter(options: options);
      final inputImage = InputImage.fromFile(tempFile);
      final result = await segmenter.processImage(inputImage);

      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      return result.foregroundBitmap;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Lỗi tách nền offline: $e"), backgroundColor: Colors.red),
        );
      }
      return null;
    } finally {
      await segmenter?.close();
    }
  }

  Future<void> _removeBgSelectedImage() async {
    if (_selectedImageIndex == null || _selectedImageIndex! >= _imageItems.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Vui lòng chạm chọn 1 ảnh ghép trên Poster trước!"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isRemovingBg = true);

    PosterImageIcon selectedItem = _imageItems[_selectedImageIndex!];
    Uint8List? newBytes = await _removeBackgroundOffline(selectedItem.imageBytes);

    if (newBytes != null) {
      setState(() {
        _imageItems[_selectedImageIndex!].imageBytes = newBytes;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Đã tách nền ảnh thành công!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    }

    setState(() => _isRemovingBg = false);
  }

  // --- BỔ SUNG: CHỌN ẢNH TỪ CAMERA HOẶC ALBUM ---
  void _pickImageSource({required Function(ImageSource source) onSelected}) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.blue),
                title: const Text('Chọn từ Thư viện (Album)'),
                onTap: () {
                  Navigator.of(context).pop();
                  onSelected(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.green),
                title: const Text('Chụp ảnh mới từ Camera'),
                onTap: () {
                  Navigator.of(context).pop();
                  onSelected(ImageSource.camera);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImage() async {
    _pickImageSource(onSelected: (source) async {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _imageItems.add(
            PosterImageIcon(
              imageBytes: bytes,
              position: const Offset(50, 50),
            ),
          );
          _selectedImageIndex = _imageItems.length - 1;
        });
      }
    });
  }

  Future<void> _pickBackgroundImage() async {
    _pickImageSource(onSelected: (source) async {
      final XFile? pickedFile = await _picker.pickImage(source: source);
      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _backgroundImageBytes = bytes;
        });
      }
    });
  }

  void _editImageItem(PosterImageIcon imgItem) {
    double tempWidth = imgItem.width;
    double tempHeight = imgItem.height;
    double tempOpacity = imgItem.opacity;
    double tempRotationDegree = (imgItem.rotation * 180 / math.pi);
    BlendMode tempBlendMode = imgItem.blendMode;
    bool tempSoftEdges = imgItem.softEdges;
    bool tempIsOval = imgItem.isOval;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Chỉnh sửa Ảnh"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SwitchListTile(
                      title: const Text("Bo ảnh hình Ovan (Oval)", style: TextStyle(fontWeight: FontWeight.bold)),
                      value: tempIsOval,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) => setDialogState(() => tempIsOval = val),
                    ),
                    const Text("Chế độ hòa trộn:", style: TextStyle(fontWeight: FontWeight.bold)),
                    DropdownButton<BlendMode>(
                      isExpanded: true,
                      value: tempBlendMode,
                      items: _blendModesMap.entries.map((entry) {
                        return DropdownMenuItem<BlendMode>(
                          value: entry.value,
                          child: Text(entry.key),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setDialogState(() => tempBlendMode = val);
                      },
                    ),
                    const SizedBox(height: 10),
                    SwitchListTile(
                      title: const Text("Làm mờ viền ảnh (Mềm viền)", style: TextStyle(fontSize: 14)),
                      value: tempSoftEdges,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) => setDialogState(() => tempSoftEdges = val),
                    ),
                    const Divider(),
                    Text("Góc xoay: ${tempRotationDegree.round()}°"),
                    Slider(
                      value: tempRotationDegree,
                      min: 0.0,
                      max: 360.0,
                      divisions: 360,
                      onChanged: (val) => setDialogState(() => tempRotationDegree = val),
                    ),
                    Text("Chiều rộng: ${tempWidth.round()} px"),
                    Slider(
                      value: tempWidth,
                      min: 30.0,
                      max: 400.0,
                      onChanged: (val) => setDialogState(() => tempWidth = val),
                    ),
                    Text("Chiều cao: ${tempHeight.round()} px"),
                    Slider(
                      value: tempHeight,
                      min: 30.0,
                      max: 400.0,
                      onChanged: (val) => setDialogState(() => tempHeight = val),
                    ),
                    Text("Độ trong suốt: ${(tempOpacity * 100).round()}%"),
                    Slider(
                      value: tempOpacity,
                      min: 0.1,
                      max: 1.0,
                      divisions: 18,
                      onChanged: (val) => setDialogState(() => tempOpacity = val),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _imageItems.remove(imgItem);
                      _selectedImageIndex = null;
                    });
                    Navigator.pop(context);
                  },
                  child: const Text("Xóa ảnh", style: TextStyle(color: Colors.red)),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Hủy"),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      imgItem.width = tempWidth;
                      imgItem.height = tempHeight;
                      imgItem.opacity = tempOpacity;
                      imgItem.rotation = tempRotationDegree * math.pi / 180;
                      imgItem.blendMode = tempBlendMode;
                      imgItem.softEdges = tempSoftEdges;
                      imgItem.isOval = tempIsOval;
                    });
                    Navigator.pop(context);
                  },
                  child: const Text("Lưu"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _editTextField(PosterTextItem item) {
    TextEditingController editController = TextEditingController(text: item.text);
    double tempFontSize = item.fontSize;
    Color tempColor = item.textColor;
    double tempOpacity = item.opacity;
    double tempRotationDegree = (item.rotation * 180 / math.pi);
    String tempFontFamily = _fontList.contains(item.fontFamily) ? item.fontFamily : _fontList.first;
    bool tempIs3D = item.is3D;
    ThreeDStyle temp3DStyle = item.threeDStyle;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Chỉnh sửa Chữ"),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: editController,
                        keyboardType: TextInputType.multiline,
                        minLines: 2,
                        maxLines: 6,
                        decoration: const InputDecoration(
                          labelText: "Nội dung",
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 15),
                      DropdownButtonFormField<String>(
                        value: tempFontFamily,
                        decoration: const InputDecoration(
                          labelText: "Font chữ",
                          border: OutlineInputBorder(),
                        ),
                        items: _fontList.map((font) {
                          return DropdownMenuItem(value: font, child: Text(font));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setDialogState(() => tempFontFamily = val);
                        },
                      ),
                      const SizedBox(height: 15),
                      SwitchListTile(
                        title: const Text("Hiệu ứng chữ 3D", style: TextStyle(fontWeight: FontWeight.bold)),
                        value: tempIs3D,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (val) => setDialogState(() => tempIs3D = val),
                      ),
                      if (tempIs3D) ...[
                        const Text("Kiểu dáng 3D:", style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 5),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              ChoiceChip(
                                label: const Text("Nổi"),
                                selected: temp3DStyle == ThreeDStyle.raised,
                                onSelected: (_) => setDialogState(() => temp3DStyle = ThreeDStyle.raised),
                              ),
                              const SizedBox(width: 5),
                              ChoiceChip(
                                label: const Text("Chìm"),
                                selected: temp3DStyle == ThreeDStyle.inset,
                                onSelected: (_) => setDialogState(() => temp3DStyle = ThreeDStyle.inset),
                              ),
                              const SizedBox(width: 5),
                              ChoiceChip(
                                label: const Text("Nghiêng"),
                                selected: temp3DStyle == ThreeDStyle.perspectiveRaised,
                                onSelected: (_) => setDialogState(() => temp3DStyle = ThreeDStyle.perspectiveRaised),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Màu chữ:", style: TextStyle(fontWeight: FontWeight.bold)),
                          GestureDetector(
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (BuildContext context) {
                                  return AlertDialog(
                                    title: const Text('Chọn màu chữ'),
                                    content: SingleChildScrollView(
                                      child: ColorPicker(
                                        pickerColor: tempColor,
                                        onColorChanged: (color) {
                                          setDialogState(() => tempColor = color);
                                        },
                                        pickerAreaHeightPercent: 0.7,
                                        enableAlpha: false,
                                      ),
                                    ),
                                    actions: [
                                      ElevatedButton(
                                        child: const Text('Đồng ý'),
                                        onPressed: () => Navigator.of(context).pop(),
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                            child: Container(
                              width: 80,
                              height: 35,
                              decoration: BoxDecoration(
                                color: tempColor,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey),
                              ),
                              child: const Center(
                                child: Text(
                                  "Đổi màu",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    shadows: [Shadow(blurRadius: 2, color: Colors.black)],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 25),
                      Text("Góc xoay: ${tempRotationDegree.round()}°"),
                      Slider(
                        value: tempRotationDegree,
                        min: 0.0,
                        max: 360.0,
                        divisions: 360,
                        onChanged: (val) => setDialogState(() => tempRotationDegree = val),
                      ),
                      Text("C cỡ chữ: ${tempFontSize.round()}"),
                      Slider(
                        value: tempFontSize,
                        min: 10.0,
                        max: 70.0,
                        onChanged: (val) => setDialogState(() => tempFontSize = val),
                      ),
                      Text("Độ trong suốt: ${(tempOpacity * 100).round()}%"),
                      Slider(
                        value: tempOpacity,
                        min: 0.1,
                        max: 1.0,
                        divisions: 18,
                        onChanged: (val) => setDialogState(() => tempOpacity = val),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    setState(() => _textItems.remove(item));
                    Navigator.pop(context);
                  },
                  child: const Text("Xóa", style: TextStyle(color: Colors.red)),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Hủy"),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      item.text = editController.text;
                      item.fontSize = tempFontSize;
                      item.textColor = tempColor;
                      item.opacity = tempOpacity;
                      item.rotation = tempRotationDegree * math.pi / 180;
                      item.fontFamily = tempFontFamily;
                      item.is3D = tempIs3D;
                      item.threeDStyle = temp3DStyle;
                    });
                    Navigator.pop(context);
                  },
                  child: const Text("Lưu"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Bỏ viền chọn xanh lá trước khi lưu/xuất file PNG
  Future<void> _captureAndExportPNG() async {
    try {
      final previousSelectedIndex = _selectedImageIndex;
      setState(() {
        _selectedImageIndex = null;
      });

      await Future.delayed(const Duration(milliseconds: 50));

      RenderRepaintBoundary boundary =
      _globalKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      setState(() {
        _selectedImageIndex = previousSelectedIndex;
      });

      if (byteData == null) return;
      Uint8List pngBytes = byteData.buffer.asUint8List();

      if (kIsWeb) {
        downloadImageWeb(pngBytes);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Đã tải Poster về thư mục Downloads!"),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        bool hasAccess = await Gal.hasAccess();
        if (!hasAccess) {
          hasAccess = await Gal.requestAccess();
          if (!hasAccess) return;
        }

        await Gal.putImageBytes(pngBytes, album: 'PosterMaker');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Đã lưu Poster vào Bộ sưu tập (Gallery)!"),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Lỗi xuất ảnh: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildBlendedImage(PosterImageIcon imgItem) {
    Widget imgWidget = Image.memory(
      imgItem.imageBytes,
      width: imgItem.width,
      height: imgItem.height,
      fit: BoxFit.cover,
    );

    if (imgItem.isOval) {
      imgWidget = ClipOval(child: imgWidget);
    }

    if (imgItem.softEdges) {
      imgWidget = ShaderMask(
        shaderCallback: (rect) {
          return const RadialGradient(
            radius: 0.85,
            colors: [Colors.black, Colors.transparent],
            stops: [0.6, 1.0],
          ).createShader(rect);
        },
        blendMode: BlendMode.dstIn,
        child: imgWidget,
      );
    }

    return imgWidget;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thiết Kế Poster Pro'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.aspect_ratio),
            onPressed: _openPosterSettings,
            tooltip: 'Kích thước & Màu nền',
          ),
          IconButton(
            icon: const Icon(Icons.save_alt),
            onPressed: _captureAndExportPNG,
            tooltip: 'Lưu Poster',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. THANH CÔNG CỤ THAO TÁC NỔI
              Card(
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Wrap(
                    alignment: WrapAlignment.spaceEvenly,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _openPosterSettings,
                        icon: const Icon(Icons.tune),
                        label: const Text("Khung & Nền"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _pickImage,
                        icon: const Icon(Icons.add_photo_alternate),
                        label: const Text("Thêm Ảnh"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _pickBackgroundImage,
                        icon: const Icon(Icons.image),
                        label: const Text("Ảnh Nền"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _isRemovingBg ? null : _removeBgSelectedImage,
                        icon: _isRemovingBg
                            ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                            : const Icon(Icons.auto_fix_high),
                        label: Text(_isRemovingBg ? "Đang tách..." : "Tách Nền"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 15),

              // 2. KHUNG HIỂN THỊ POSTER
              Center(
                child: GestureDetector(
                  onTap: () {
                    // Chạm ra vùng trống để bỏ chọn ảnh (ẩn viền xanh)
                    setState(() {
                      _selectedImageIndex = null;
                    });
                  },
                  child: RepaintBoundary(
                    key: _globalKey,
                    child: Container(
                      width: _posterWidth,
                      height: _posterHeight,
                      decoration: BoxDecoration(
                        color: _backgroundColor,
                        image: _backgroundImageBytes != null
                            ? DecorationImage(
                          image: MemoryImage(_backgroundImageBytes!),
                          fit: BoxFit.cover,
                        )
                            : null,
                      ),
                      child: Stack(
                        children: [
                          // Render Ảnh Ghép
                          ..._imageItems.asMap().entries.map((entry) {
                            int index = entry.key;
                            PosterImageIcon imgItem = entry.value;
                            bool isSelected = _selectedImageIndex == index;

                            return Positioned(
                              left: imgItem.position.dx,
                              top: imgItem.position.dy,
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedImageIndex = index;
                                  });
                                },
                                onPanUpdate: (details) {
                                  setState(() {
                                    _selectedImageIndex = index;
                                    imgItem.position += details.delta;
                                  });
                                },
                                onDoubleTap: () => _editImageItem(imgItem),
                                child: Container(
                                  decoration: BoxDecoration(
                                    border: isSelected
                                        ? Border.all(color: Colors.greenAccent, width: 2)
                                        : null,
                                  ),
                                  child: Transform.rotate(
                                    angle: imgItem.rotation,
                                    child: Opacity(
                                      opacity: imgItem.opacity,
                                      child: _buildBlendedImage(imgItem),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),

                          // Render Chữ
                          ..._textItems.map((item) {
                            return Positioned(
                              left: item.position.dx,
                              top: item.position.dy,
                              child: GestureDetector(
                                onPanUpdate: (details) {
                                  setState(() => item.position += details.delta);
                                },
                                onDoubleTap: () => _editTextField(item),
                                child: Transform.rotate(
                                  angle: item.rotation,
                                  child: Opacity(
                                    opacity: item.opacity,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      child: _buildTextWidget(item),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 3. KHU VỰC THÊM CHỮ MỚI
              Card(
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Thêm Chữ Mới", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _textController,
                              decoration: const InputDecoration(
                                hintText: "Nhập nội dung...",
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton(
                            onPressed: _addNewText,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                            ),
                            child: const Text("Thêm"),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _newFontFamily,
                              decoration: const InputDecoration(labelText: "Font chữ", isDense: true),
                              items: _fontList.map((font) {
                                return DropdownMenuItem(value: font, child: Text(font));
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _newFontFamily = val);
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (BuildContext context) {
                                  return AlertDialog(
                                    title: const Text('Chọn màu chữ mới'),
                                    content: SingleChildScrollView(
                                      child: ColorPicker(
                                        pickerColor: _newTextColor,
                                        onColorChanged: (color) {
                                          setState(() => _newTextColor = color);
                                        },
                                        pickerAreaHeightPercent: 0.7,
                                        enableAlpha: false,
                                      ),
                                    ),
                                    actions: [
                                      ElevatedButton(
                                        child: const Text('Đồng ý'),
                                        onPressed: () => Navigator.of(context).pop(),
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: _newTextColor,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey),
                              ),
                              child: const Text(
                                "Màu chữ",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  shadows: [Shadow(blurRadius: 3, color: Colors.black)],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          FilterChip(
                            label: const Text("Chữ 3D"),
                            selected: _newIs3D,
                            onSelected: (val) => setState(() => _newIs3D = val),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}