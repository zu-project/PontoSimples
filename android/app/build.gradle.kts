plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.zuproject.checkponto"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    // Configuração de assinatura
    signingConfigs {
        create("release") {
            storeFile = file("keystore.jks") // Caminho para o arquivo de chave
            storePassword = "asdasd123"         // Senha do keystore
            keyAlias = "minha-chave"              // Alias da chave
            keyPassword = "asdasd123"     // Senha da chave
        }
    }

    defaultConfig {
        applicationId = "com.zuproject.checkponto" // Deve ser único na Play Store
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode  // Usa o versionCode do pubspec.yaml
        versionName = flutter.versionName        // Versão visível ao usuário
        ndkVersion = "27.0.12077973"
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release") // Usa a configuração de assinatura
            isMinifyEnabled = true                       // Ativa minificação para reduzir o tamanho
            isShrinkResources = true                    // Remove recursos não utilizados
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            ndk {
                debugSymbolLevel = "FULL" // Gera símbolos completos para depuração nativa
            }
        }
        debug {
            signingConfig = signingConfigs.getByName("debug") // Mantém debug para testes locais
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Dependências adicionais podem ser adicionadas aqui, se necessário
}