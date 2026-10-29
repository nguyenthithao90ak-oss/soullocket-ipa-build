import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Bộ nạp GLB cục bộ cho hai model do dự án tạo. Không tải URI hay texture mạng.
/// Hỗ trợ mesh TRIANGLES, skin weights, normal, material và clip TRS.
final class Companion3DAssets extends ChangeNotifier {
  Companion3DAssets._();
  static final instance = Companion3DAssets._();
  final Map<bool, Companion3DModel> _models = {};
  Future<void>? _loading;
  Object? loadError;

  Companion3DModel? model(bool bear) => _models[bear];

  Future<void> load() => _loading ??= _load();

  Future<void> _load() async {
    try {
      final bunny = Companion3DModel.decode(
        await rootBundle.load('assets/companions_3d/bunny.glb'),
      );
      final bear = Companion3DModel.decode(
        await rootBundle.load('assets/companions_3d/bear.glb'),
      );
      // Công bố cả cặp sau khi giải mã xong, tránh một frame hai renderer khác nhau.
      _models.addAll({false: bunny, true: bear});
    } catch (error, stack) {
      loadError = error;
      debugPrint('Không nạp được model đồng hành 3D: $error');
      debugPrintStack(stackTrace: stack);
    }
    notifyListeners();
  }
}

final class Companion3DModel {
  Companion3DModel._(
    this.nodes,
    this.meshes,
    this.materials,
    this.skins,
    this.clips,
  );

  final List<Companion3DNode> nodes;
  final List<Companion3DMesh> meshes;
  final List<Companion3DMaterial> materials;
  final List<Companion3DSkin> skins;
  final Map<String, List<Companion3DChannel>> clips;

  static Companion3DModel decode(ByteData bytes) {
    if (bytes.lengthInBytes < 20 ||
        bytes.getUint32(0, Endian.little) != 0x46546c67 ||
        bytes.getUint32(4, Endian.little) != 2 ||
        bytes.getUint32(8, Endian.little) != bytes.lengthInBytes) {
      throw const FormatException('GLB header không hợp lệ');
    }
    Map<String, dynamic>? json;
    ByteData? binary;
    for (var offset = 12; offset + 8 <= bytes.lengthInBytes;) {
      final length = bytes.getUint32(offset, Endian.little);
      final type = bytes.getUint32(offset + 4, Endian.little);
      offset += 8;
      if (offset + length > bytes.lengthInBytes) {
        throw const FormatException('GLB chunk bị cắt');
      }
      final chunk = bytes.buffer.asUint8List(
        bytes.offsetInBytes + offset,
        length,
      );
      if (type == 0x4e4f534a) {
        json = jsonDecode(utf8.decode(chunk)) as Map<String, dynamic>;
      }
      if (type == 0x004e4942) binary = ByteData.sublistView(chunk);
      offset += length;
    }
    if (json == null || binary == null) {
      throw const FormatException('GLB thiếu dữ liệu');
    }
    if (json['textures'] != null || json['extensionsRequired'] != null) {
      throw const FormatException(
        'Model cần tính năng ngoài renderer đồng hành',
      );
    }
    final source = json;
    final bin = binary;
    Float64List read(int id) {
      final accessor = source['accessors'][id] as Map;
      final view = source['bufferViews'][accessor['bufferView']] as Map;
      final width = switch (accessor['type']) {
        'SCALAR' => 1,
        'VEC3' => 3,
        'VEC4' => 4,
        'MAT4' => 16,
        _ => throw const FormatException('Accessor không hỗ trợ'),
      };
      final type = accessor['componentType'] as int;
      final size = switch (type) {
        5126 => 4,
        5123 => 2,
        _ => throw const FormatException('Component không hỗ trợ'),
      };
      final start =
          (view['byteOffset'] as int? ?? 0) +
          (accessor['byteOffset'] as int? ?? 0);
      final count = accessor['count'] as int;
      final stride = view['byteStride'] as int? ?? width * size;
      if (count < 0 ||
          count > 1000000 ||
          start < 0 ||
          start + (count - 1) * stride + width * size > bin.lengthInBytes) {
        throw const FormatException('Accessor vượt buffer');
      }
      final values = Float64List(count * width);
      for (var i = 0; i < count; i++) {
        for (var k = 0; k < width; k++) {
          final at = start + i * stride + k * size;
          final value = type == 5126
              ? bin.getFloat32(at, Endian.little)
              : bin.getUint16(at, Endian.little).toDouble();
          if (!value.isFinite) {
            throw const FormatException('Vertex không hữu hạn');
          }
          values[i * width + k] = value;
        }
      }
      return values;
    }

    List<double> vector(dynamic value, List<double> fallback) => value == null
        ? fallback
        : (value as List).map((v) => (v as num).toDouble()).toList();
    final materials = [
      for (final m in source['materials'] as List)
        Companion3DMaterial(
          vector(m['pbrMetallicRoughness']['baseColorFactor'], [1, 1, 1, 1]),
          (m['pbrMetallicRoughness']['roughnessFactor'] as num? ?? 1)
              .toDouble(),
        ),
    ];
    final meshes = <Companion3DMesh>[];
    for (final m in source['meshes'] as List) {
      final p = (m['primitives'] as List).single as Map;
      if ((p['mode'] ?? 4) != 4) {
        throw const FormatException('Mesh không phải tam giác');
      }
      final positions = read(p['attributes']['POSITION'] as int);
      final normals = read(p['attributes']['NORMAL'] as int);
      final indices = read(p['indices'] as int).map((v) => v.toInt()).toList();
      if (positions.length != normals.length ||
          indices.length % 3 != 0 ||
          indices.any((v) => v < 0 || v * 3 >= positions.length)) {
        throw const FormatException('Mesh indices không hợp lệ');
      }
      final colorId = p['attributes']['COLOR_0'] as int?;
      final jointId = p['attributes']['JOINTS_0'] as int?;
      final weightId = p['attributes']['WEIGHTS_0'] as int?;
      final colors = colorId == null ? null : read(colorId);
      final joints = jointId == null ? null : read(jointId);
      final weights = weightId == null ? null : read(weightId);
      final vertexCount = positions.length ~/ 3;
      if ((colors != null && colors.length != vertexCount * 4) ||
          (joints == null) != (weights == null) ||
          (joints != null &&
              (joints.length != vertexCount * 4 ||
                  weights!.length != joints.length))) {
        throw const FormatException('Thuộc tính vertex không khớp mesh');
      }
      if (weights != null) {
        for (var v = 0; v < vertexCount; v++) {
          var sum = 0.0;
          for (var k = 0; k < 4; k++) {
            final at = v * 4 + k;
            if (weights[at] < 0 ||
                weights[at] > 1 ||
                joints![at] < 0 ||
                joints[at] != joints[at].roundToDouble()) {
              throw const FormatException('Skin weights không hợp lệ');
            }
            sum += weights[at];
          }
          if ((sum - 1).abs() > .001) {
            throw const FormatException('Tổng skin weights phải bằng một');
          }
        }
      }
      meshes.add(
        Companion3DMesh(
          positions,
          normals,
          indices,
          p['material'] as int,
          colors,
          joints,
          weights,
        ),
      );
    }
    final rawNodes = source['nodes'] as List;
    final parents = List.filled(rawNodes.length, -1);
    for (var i = 0; i < rawNodes.length; i++) {
      for (final child in rawNodes[i]['children'] as List? ?? const []) {
        // Asset được xuất theo thứ tự cha trước con; từ chối chu trình/cha trùng.
        if (child is! int ||
            child <= i ||
            child >= rawNodes.length ||
            parents[child] != -1) {
          throw const FormatException('Rig phân cấp không hợp lệ');
        }
        parents[child] = i;
      }
    }
    final nodes = <Companion3DNode>[];
    for (var i = 0; i < rawNodes.length; i++) {
      final n = rawNodes[i] as Map;
      nodes.add(
        Companion3DNode(
          n['name'] as String? ?? '',
          parents[i],
          n['mesh'] as int?,
          n['skin'] as int?,
          vector(n['translation'], [0, 0, 0]),
          vector(n['rotation'], [0, 0, 0, 1]),
          vector(n['scale'], [1, 1, 1]),
          n['extras']?['slot'] as String?,
          n['extras']?['value'] as String?,
        ),
      );
    }
    final skins = <Companion3DSkin>[];
    for (final skin in source['skins'] as List? ?? const []) {
      final joints = (skin['joints'] as List).cast<int>();
      final inverseBind = read(skin['inverseBindMatrices'] as int);
      if (joints.isEmpty ||
          joints.any((j) => j < 0 || j >= nodes.length) ||
          inverseBind.length != joints.length * 16) {
        throw const FormatException('Skin không khớp rig');
      }
      skins.add(Companion3DSkin(joints, inverseBind));
    }
    for (final node in nodes) {
      if (node.skin == null) continue;
      if (node.skin! < 0 || node.skin! >= skins.length || node.mesh == null) {
        throw const FormatException('Node skin không hợp lệ');
      }
      final mesh = meshes[node.mesh!];
      if (mesh.joints == null ||
          mesh.joints!.any((j) => j >= skins[node.skin!].joints.length)) {
        throw const FormatException('Mesh tham chiếu xương không tồn tại');
      }
    }
    final clips = <String, List<Companion3DChannel>>{};
    for (final animation in source['animations'] as List? ?? const []) {
      final channels = <Companion3DChannel>[];
      for (final channel in animation['channels'] as List) {
        final sampler = animation['samplers'][channel['sampler']];
        if ((sampler['interpolation'] ?? 'LINEAR') != 'LINEAR') {
          throw const FormatException('Clip cần LINEAR');
        }
        final times = read(sampler['input'] as int);
        final values = read(sampler['output'] as int);
        final property = channel['target']['path'] as String;
        if (times.length < 2 ||
            times.last <= 0 ||
            values.length != times.length * (property == 'rotation' ? 4 : 3)) {
          throw const FormatException('Clip không hợp lệ');
        }
        channels.add(
          Companion3DChannel(
            channel['target']['node'] as int,
            property,
            times,
            values,
          ),
        );
      }
      clips[animation['name'] as String] = channels;
    }
    return Companion3DModel._(nodes, meshes, materials, skins, clips);
  }
}

final class Companion3DNode {
  const Companion3DNode(
    this.name,
    this.parent,
    this.mesh,
    this.skin,
    this.translation,
    this.rotation,
    this.scale,
    this.slot,
    this.variant,
  );
  final String name;
  final int parent;
  final int? mesh, skin;
  final List<double> translation, rotation, scale;
  final String? slot, variant;
}

final class Companion3DMesh {
  const Companion3DMesh(
    this.positions,
    this.normals,
    this.indices,
    this.material,
    this.colors,
    this.joints,
    this.weights,
  );
  final Float64List positions, normals;
  final Float64List? colors, joints, weights;
  final List<int> indices;
  final int material;
}

final class Companion3DSkin {
  const Companion3DSkin(this.joints, this.inverseBind);
  final List<int> joints;

  /// MAT4 column-major theo glTF, một ma trận cho mỗi xương.
  final Float64List inverseBind;
}

final class Companion3DMaterial {
  const Companion3DMaterial(this.color, this.roughness);
  final List<double> color;
  final double roughness;
}

final class Companion3DChannel {
  const Companion3DChannel(this.node, this.property, this.times, this.values);
  final int node;
  final String property;
  final Float64List times, values;
}
