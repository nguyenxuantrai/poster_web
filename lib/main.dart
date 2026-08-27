import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:gal/gal.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:text_3d/text_3d.dart';
import 'package:google_mlkit_subject_segmentation/google_mlkit_subject_segmentation.dart';
import 'package:image/image.dart' as img;

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

// 1. Model Chữ (Bổ sung cấu hình 3D)
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

// 2. Model Hình Ảnh
class PosterImageIcon {
  File imageFile;
  Offset position;
  double width;
  double height;
  double opacity;
  double rotation;
  BlendMode blendMode;
  bool softEdges;
  bool isOval;

  PosterImageIcon({
    required this.imageFile,
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

  // Khai báo cấu hình tạo chữ mới
  Color _newTextColor = Colors.black;
  double _newFontSize = 22.0;
  String _newFontFamily = 'Dancing Script';
  bool _newIs3D = false;
  ThreeDStyle _newThreeDStyle = ThreeDStyle.raised;

  // Danh sách font (Bao gồm Google Fonts và Font Hệ thống)
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
    'Arial',            // Font hệ thống
    'Times New Roman',  // Font hệ thống
  ];

  final ImagePicker _picker = ImagePicker();

  double _posterWidth = 550.0;
  double _posterHeight = 700.0;

  File? _backgroundImageFile;
  Color _backgroundColor = Colors.amber[300]!;

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

  // --- HÀM LẤY FONT STYLE THÔNG MINH ---
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

  // --- HÀM WIDGET HIỂN THỊ CHỮ 2D HOẶC 3D ---
  Widget _buildTextWidget(PosterTextItem item) {
    TextStyle style = _getFontFamilyStyle(
      item.fontFamily,
      item.fontSize,
      item.textColor,
    );

    if (!item.is3D) {
      return Text(
        item.text,
        style: style,
      );
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

  Future<void> _pickImageFromGallery() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 85,
    );
    if (pickedFile != null) {
      setState(() {
        _imageItems.add(
          PosterImageIcon(
            imageFile: File(pickedFile.path),
            position: const Offset(50, 50),
          ),
        );
      });
    }
  }

  Future<void> _pickBackgroundImage() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _backgroundImageFile = File(pickedFile.path);
      });
    }
  }

  // --- HÀM TÁCH NỀN ẢNH VIA REMOVE.BG API ---
  /*
  Future<File?> _removeBackground(File imageFile) async {
    const String apiKey = "yGXJ4M4A6PPtd3Jh7p8QvZRz";

    if (apiKey.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Vui lòng nhập API Key hợp lệ!")),
        );
      }
      return null;
    }

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('https://api.remove.bg/v1.0/removebg'),
      );
      request.headers['X-Api-Key'] = apiKey;
      request.files.add(await http.MultipartFile.fromPath('image_file', imageFile.path));
      request.fields['size'] = 'auto';

      var response = await request.send();

      if (response.statusCode == 200) {
        var bytes = await response.stream.toBytes();
        Directory tempDir = Directory.systemTemp;
        String tempPath = '${tempDir.path}/no_bg_${DateTime.now().millisecondsSinceEpoch}.png';
        File noBgFile = File(tempPath);
        await noBgFile.writeAsBytes(bytes);
        return noBgFile;
      } else {
        var responseData = await response.stream.bytesToString();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Lỗi (${response.statusCode}): $responseData")),
          );
        }
        return null;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Tách nền thất bại: $e")),
        );
      }
      return null;
    }
  }
  */
//--- hàm tach nền offline
  Future<File?> _removeBackground(File imageFile) async {
    SubjectSegmenter? segmenter;
    try {
      // 1. Tạo options đúng tham số bắt buộc của package
      final options = SubjectSegmenterOptions(
        enableForegroundBitmap: true,         // Lấy ảnh chủ thể
        enableForegroundConfidenceMask: true, // Lấy mặt nạ phân giải
        enableMultipleSubjects: SubjectResultOptions(
          enableConfidenceMask: false,
          enableSubjectBitmap: false,
        ),
      );

      // 2. Khởi tạo Segmenter
      segmenter = SubjectSegmenter(options: options);

      final inputImage = InputImage.fromFile(imageFile);
      final result = await segmenter.processImage(inputImage);

      // 3. Trả về mảng byte ảnh foreground
      final Uint8List? foregroundBytes = result.foregroundBitmap;

      if (foregroundBytes != null && foregroundBytes.isNotEmpty) {
        Directory tempDir = Directory.systemTemp;
        String tempPath = '${tempDir.path}/no_bg_${DateTime.now().millisecondsSinceEpoch}.png';
        File noBgFile = File(tempPath);
        await noBgFile.writeAsBytes(foregroundBytes);
        return noBgFile;
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Không phát hiện được người hoặc vật thể trong ảnh!"),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return null;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Lỗi tách nền offline: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    } finally {
      // Luôn giải phóng tài nguyên RAM
      await segmenter?.close();
    }
  }
  // Hộp thoại chỉnh sửa ẢNH
  void _editImageItem(PosterImageIcon imgItem) {
    double tempWidth = imgItem.width;
    double tempHeight = imgItem.height;
    double tempOpacity = imgItem.opacity;
    double tempRotationDegree = (imgItem.rotation * 180 / math.pi);
    BlendMode tempBlendMode = imgItem.blendMode;
    bool tempSoftEdges = imgItem.softEdges;
    bool tempIsOval = imgItem.isOval;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Chỉnh sửa & Xử lý Ảnh"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ElevatedButton.icon(
                      onPressed: isLoading
                          ? null
                          : () async {
                        setDialogState(() => isLoading = true);
                        File? noBgFile = await _removeBackground(imgItem.imageFile);
                        setDialogState(() => isLoading = false);

                        if (noBgFile != null) {
                          setState(() {
                            imgItem.imageFile = noBgFile;
                          });
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Đã tách nền thành công!"),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        }
                      },
                      icon: isLoading
                          ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                          : const Icon(Icons.auto_fix_high),
                      label: Text(isLoading ? "Đang xử lý tách nền..." : "Tách nền tự động (Remove BG)"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 42),
                      ),
                    ),
                    const Divider(height: 25),

                    SwitchListTile(
                      title: const Text("Bo ảnh hình Ovan (Oval)", style: TextStyle(fontWeight: FontWeight.bold)),
                      value: tempIsOval,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) => setDialogState(() => tempIsOval = val),
                    ),

                    const Text("Chế độ hòa trộn với nền:", style: TextStyle(fontWeight: FontWeight.bold)),
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
                    setState(() => _imageItems.remove(imgItem));
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

  // Hộp thoại chỉnh CHỮ (Có cấu hình 3D)
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
                          labelText: "Nội dung (ấn Enter để xuống dòng)",
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

                      // Bật/Tắt hiệu ứng 3D khi chỉnh sửa
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

  // Hàm Xuất PNG
  Future<void> _captureAndExportPNG() async {
    try {
      bool hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        hasAccess = await Gal.requestAccess();
        if (!hasAccess) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Chưa cấp quyền truy cập Thư viện ảnh!")),
            );
          }
          return;
        }
      }

      RenderRepaintBoundary boundary =
      _globalKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      await Gal.putImageBytes(pngBytes, album: 'PosterMaker');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Đã lưu Poster vào Thư viện ảnh thành công!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Lưu ảnh thất bại: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildBlendedImage(PosterImageIcon imgItem) {
    Widget imgWidget = Image.file(
      imgItem.imageFile,
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
        title: const Text('Thiết Kế Poster'),
        actions: [
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
            children: [
              Center(
                child: RepaintBoundary(
                  key: _globalKey,
                  child: Container(
                    width: _posterWidth,
                    height: _posterHeight,
                    decoration: BoxDecoration(
                      color: _backgroundColor,
                      image: _backgroundImageFile != null
                          ? DecorationImage(
                        image: FileImage(_backgroundImageFile!),
                        fit: BoxFit.cover,
                      )
                          : null,
                    ),
                    child: Stack(
                      children: [
                        ..._imageItems.map((imgItem) {
                          return Positioned(
                            left: imgItem.position.dx,
                            top: imgItem.position.dy,
                            child: GestureDetector(
                              onPanUpdate: (details) {
                                setState(() => imgItem.position += details.delta);
                              },
                              onDoubleTap: () => _editImageItem(imgItem),
                              child: Transform.rotate(
                                angle: imgItem.rotation,
                                child: Opacity(
                                  opacity: imgItem.opacity,
                                  child: _buildBlendedImage(imgItem),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
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
              const SizedBox(height: 20),

              // CẤU HÌNH KÍCH THƯỚC VÀ MÀU NỀN
              ExpansionTile(
                title: const Text(
                  "Chỉnh kích thước & Màu nền Poster",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                children: [
                  Text("Chiều rộng khung: ${_posterWidth.round()} px"),
                  Slider(
                    value: _posterWidth,
                    min: 300.0,
                    max: 600.0,
                    onChanged: (val) => setState(() => _posterWidth = val),
                  ),
                  Text("Chiều cao khung: ${_posterHeight.round()} px"),
                  Slider(
                    value: _posterHeight,
                    min: 300.0,
                    max: 1080.0,
                    onChanged: (val) => setState(() => _posterHeight = val),
                  ),
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Màu nền Poster:",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        GestureDetector(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (BuildContext context) {
                                Color tempColor = _backgroundColor;
                                return AlertDialog(
                                  title: const Text('Chọn màu nền Poster'),
                                  content: SingleChildScrollView(
                                    child: ColorPicker(
                                      pickerColor: tempColor,
                                      onColorChanged: (color) => tempColor = color,
                                      pickerAreaHeightPercent: 0.7,
                                      enableAlpha: false,
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      child: const Text('Hủy'),
                                      onPressed: () => Navigator.of(context).pop(),
                                    ),
                                    ElevatedButton(
                                      child: const Text('Đồng ý'),
                                      onPressed: () {
                                        setState(() => _backgroundColor = tempColor);
                                        Navigator.of(context).pop();
                                      },
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                          child: Container(
                            width: 90,
                            height: 38,
                            decoration: BoxDecoration(
                              color: _backgroundColor,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey, width: 2),
                            ),
                            child: const Center(
                              child: Text(
                                "Đổi màu",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  shadows: [Shadow(blurRadius: 3, color: Colors.black)],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _pickBackgroundImage,
                        icon: const Icon(Icons.wallpaper),
                        label: const Text("Chọn ảnh nền"),
                      ),
                      if (_backgroundImageFile != null)
                        TextButton(
                          onPressed: () => setState(() => _backgroundImageFile = null),
                          child: const Text("Xóa ảnh nền", style: TextStyle(color: Colors.red)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
              ),

              // CARD THÊM CHỮ MỚI & THÊM ẢNH (Bổ sung phần bị thiếu)
              Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Thêm chữ mới vào Poster",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _textController,
                        decoration: const InputDecoration(
                          labelText: "Nhập nội dung chữ",
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),

                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _newFontFamily,
                              decoration: const InputDecoration(
                                labelText: "Font chữ",
                                border: OutlineInputBorder(),
                              ),
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
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: _newTextColor,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Công tắc Bật 3D khi thêm chữ mới
                      SwitchListTile(
                        title: const Text("Tạo chữ 3D", style: TextStyle(fontWeight: FontWeight.bold)),
                        value: _newIs3D,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (val) => setState(() => _newIs3D = val),
                      ),

                      if (_newIs3D) ...[
                        Row(
                          children: [
                            ChoiceChip(
                              label: const Text("Nổi"),
                              selected: _newThreeDStyle == ThreeDStyle.raised,
                              onSelected: (_) => setState(() => _newThreeDStyle = ThreeDStyle.raised),
                            ),
                            const SizedBox(width: 8),
                            ChoiceChip(
                              label: const Text("Chìm"),
                              selected: _newThreeDStyle == ThreeDStyle.inset,
                              onSelected: (_) => setState(() => _newThreeDStyle = ThreeDStyle.inset),
                            ),
                            const SizedBox(width: 8),
                            ChoiceChip(
                              label: const Text("Nghiêng"),
                              selected: _newThreeDStyle == ThreeDStyle.perspectiveRaised,
                              onSelected: (_) => setState(() => _newThreeDStyle = ThreeDStyle.perspectiveRaised),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                      ],

                      ElevatedButton.icon(
                        onPressed: _addNewText,
                        icon: const Icon(Icons.add),
                        label: const Text("Thêm Chữ"),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 45),
                        ),
                      ),
                      const Divider(height: 30),

                      ElevatedButton.icon(
                        onPressed: _pickImageFromGallery,
                        icon: const Icon(Icons.image),
                        label: const Text("Thêm Hình Ảnh / Logo từ máy"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 45),
                        ),
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