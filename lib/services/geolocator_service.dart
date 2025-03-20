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
        Placemark firstPlace = placemarks[0];
        String? cidade = firstPlace.locality;
        String? estado = firstPlace.administrativeArea;
        String? bairro = firstPlace.subLocality;
        //Remover a linha abaixo, pois formattedAddress não existe na classe Placemark
        //String? formattedAddress = firstPlace.formattedAddress; // Obter o endereço formatado

        // 1. Tentar encontrar a cidade nos outros resultados
        for (Placemark place in placemarks) {
          if (place.locality != null && place.locality!.isNotEmpty) {
            cidade = place.locality;
            break; // Encontrou a cidade, sair do loop
          }
        }

        // 2. Se encontrou a cidade, combinar com o estado (se disponível)
        if (cidade != null && cidade.isNotEmpty) {
          if (estado != null && estado.isNotEmpty) {
            cidade = "$cidade, $estado";
          }
          return cidade;
        } else {
          // 3. Se não encontrou a cidade, usar bairro e estado (se disponíveis)
          if (bairro != null && bairro.isNotEmpty && estado != null && estado.isNotEmpty) {
            cidade = "$bairro, $estado";
            print("Usando Bairro e Estado: $cidade");
            return cidade;
          } else if (estado != null && estado.isNotEmpty) {
            // 4. Se só tiver o estado, usar ele
            print("Usando Estado: $estado");
            return estado;
          } else {
            print("Cidade/Bairro/Estado não encontrados.");
            return null;
          }
        }
      } else {
        print("Nenhum resultado encontrado para as coordenadas.");
        return null;
      }
    } catch (e) {
      print("Erro ao obter a cidade: $e");
      return null;
    }
  }
}