import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class GeolocatorService {
  Future<Position?> getCurrentLocation() async {
    try {
      return await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
    } catch (e) {
      print("Erro ao obter a localização: $e");
      return null;
    }
  }

  Future<String?> getCityFromCoordinates(double latitude, double longitude) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(latitude, longitude);

      if (placemarks.isNotEmpty) {
        String? cidade;
        String? estado;
        String? bairro;

        // Iterar sobre todos os Placemarks para encontrar a cidade
        for (Placemark place in placemarks) {
          print("Placemark: ${place.toJson()}"); // Log detalhado para debug

          // Priorizar 'locality' como cidade
          if (place.locality != null && place.locality!.isNotEmpty) {
            cidade = place.locality;
            estado = place.administrativeArea ?? '';
            bairro = place.subLocality ?? '';
            break; // Encontrou a cidade, sai do loop
          }
        }

        // Se não encontrou 'locality', tentar alternativas
        if (cidade == null || cidade.isEmpty) {
          for (Placemark place in placemarks) {
            // Tentar usar 'subAdministrativeArea' (pode conter cidade em alguns casos)
            if (place.subAdministrativeArea != null && place.subAdministrativeArea!.isNotEmpty) {
              cidade = place.subAdministrativeArea;
              estado = place.administrativeArea ?? '';
              bairro = place.subLocality ?? '';
              break;
            }
            // Última tentativa: usar 'name' como cidade (pode ser o nome do lugar)
            else if (place.name != null && place.name!.isNotEmpty) {
              cidade = place.name;
              estado = place.administrativeArea ?? '';
              bairro = place.subLocality ?? '';
              break;
            }
          }
        }

        // Montar o resultado final
        if (cidade != null && cidade.isNotEmpty) {
          String resultado = cidade;
          if (bairro != null && bairro.isNotEmpty) {
            resultado = "$bairro, $resultado";
          }
          if (estado != null && estado.isNotEmpty) {
            resultado = "$resultado, $estado";
          }
          print("Cidade retornada: $resultado");
          return resultado;
        } else if (estado != null && estado.isNotEmpty) {
          print("Apenas estado disponível: $estado");
          return estado; // Fallback para apenas o estado
        } else {
          print("Nenhum dado útil encontrado.");
          return "Localização Desconhecida";
        }
      } else {
        print("Nenhum Placemark retornado para as coordenadas.");
        return "Localização Desconhecida";
      }
    } catch (e) {
      print("Erro ao obter a cidade: $e");
      return "Erro ao obter localização";
    }
  }
}