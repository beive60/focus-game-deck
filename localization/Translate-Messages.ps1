# Translate-Messages.ps1
# Script to translate untranslated English keys in messages.json

$messagesPath = Join-Path $PSScriptRoot "messages.json"
$messages = Get-Content $messagesPath -Raw -Encoding UTF8 | ConvertFrom-Json

# Translation mappings for common technical terms and UI elements
$commonTranslations = @{
    ru = @{
        "Warning: No path specified for app" = "Предупреждение: Не указан путь для приложения"
        "Application started" = "Приложение запущено"
        "Warning: No process name specified for app" = "Предупреждение: Не указано имя процесса для приложения"
        "App process stopped" = "Процесс приложения остановлен"
        "App process not found" = "Процесс приложения не найден"
        "App process is not running" = "Процесс приложения не запущен"
        "Graceful shutdown failed, using force termination for" = "Нормальное завершение не удалось, принудительное завершение для"
        "Initiated graceful shutdown for" = "Инициировано нормальное завершение для"
        "Graceful shutdown successful for" = "Нормальное завершение успешно для"
        "Graceful shutdown timed out for" = "Превышено время ожидания нормального завершения для"
        "Graceful shutdown failed for" = "Нормальное завершение не удалось для"
        "Force termination successful for" = "Принудительное завершение успешно для"
        "Force termination failed for" = "Принудительное завершение не удалось для"
        "App hotkey toggled for" = "Горячая клавиша приложения переключена для"
        "Warning: App not defined" = "Предупреждение: Приложение не определено"
        "Configuration validation passed" = "Проверка конфигурации пройдена"
        "Configuration validation failed" = "Проверка конфигурации не пройдена"
        "Authentication required" = "Требуется аутентификация"
        "OBS authentication failed" = "Аутентификация OBS не удалась"
        "OBS authentication successful" = "Аутентификация OBS успешна"
        "OBS connection error" = "Ошибка подключения к OBS"
        "OBS replay buffer started" = "Буфер повтора OBS запущен"
        "Replay buffer start error" = "Ошибка запуска буфера повтора"
        "OBS replay buffer stopped" = "Буфер повтора OBS остановлен"
        "Replay buffer stop error" = "Ошибка остановки буфера повтора"
        "OBS is already running" = "OBS уже запущен"
        "Starting OBS" = "Запуск OBS"
        "OBS startup complete" = "Запуск OBS завершен"
        "OBS startup failed" = "Запуск OBS не удался"
        "WebSocket receive error" = "Ошибка приема WebSocket"
        "Failed to connect to OBS" = "Не удалось подключиться к OBS"
        "Connected to OBS WebSocket" = "Подключено к OBS WebSocket"
        "Error receiving Hello message" = "Ошибка получения сообщения Hello"
    }
    fr = @{
        "Warning: No path specified for app" = "Avertissement: Aucun chemin spécifié pour l'application"
        "Application started" = "Application démarrée"
        "Warning: No process name specified for app" = "Avertissement: Aucun nom de processus spécifié pour l'application"
        "App process stopped" = "Processus de l'application arrêté"
        "App process not found" = "Processus de l'application introuvable"
        "App process is not running" = "Le processus de l'application n'est pas en cours d'exécution"
        "Graceful shutdown failed, using force termination for" = "L'arrêt en douceur a échoué, utilisation de la terminaison forcée pour"
        "Initiated graceful shutdown for" = "Arrêt en douceur initié pour"
        "Graceful shutdown successful for" = "Arrêt en douceur réussi pour"
        "Graceful shutdown timed out for" = "Délai d'arrêt en douceur dépassé pour"
        "Graceful shutdown failed for" = "L'arrêt en douceur a échoué pour"
        "Force termination successful for" = "Terminaison forcée réussie pour"
        "Force termination failed for" = "La terminaison forcée a échoué pour"
        "App hotkey toggled for" = "Raccourci clavier de l'application basculé pour"
        "Warning: App not defined" = "Avertissement: Application non définie"
        "Configuration validation passed" = "Validation de la configuration réussie"
        "Configuration validation failed" = "Échec de la validation de la configuration"
        "Authentication required" = "Authentification requise"
        "OBS authentication failed" = "Échec de l'authentification OBS"
        "OBS authentication successful" = "Authentification OBS réussie"
        "OBS connection error" = "Erreur de connexion OBS"
        "OBS replay buffer started" = "Tampon de relecture OBS démarré"
        "Replay buffer start error" = "Erreur de démarrage du tampon de relecture"
        "OBS replay buffer stopped" = "Tampon de relecture OBS arrêté"
        "Replay buffer stop error" = "Erreur d'arrêt du tampon de relecture"
        "OBS is already running" = "OBS est déjà en cours d'exécution"
        "Starting OBS" = "Démarrage d'OBS"
        "OBS startup complete" = "Démarrage d'OBS terminé"
        "OBS startup failed" = "Échec du démarrage d'OBS"
        "WebSocket receive error" = "Erreur de réception WebSocket"
        "Failed to connect to OBS" = "Échec de la connexion à OBS"
        "Connected to OBS WebSocket" = "Connecté au WebSocket OBS"
        "Error receiving Hello message" = "Erreur lors de la réception du message Hello"
    }
    es = @{
        "Warning: No path specified for app" = "Advertencia: No se especificó ruta para la aplicación"
        "Application started" = "Aplicación iniciada"
        "Warning: No process name specified for app" = "Advertencia: No se especificó nombre de proceso para la aplicación"
        "App process stopped" = "Proceso de aplicación detenido"
        "App process not found" = "Proceso de aplicación no encontrado"
        "App process is not running" = "El proceso de la aplicación no está en ejecución"
        "Graceful shutdown failed, using force termination for" = "El cierre controlado falló, usando terminación forzada para"
        "Initiated graceful shutdown for" = "Se inició el cierre controlado para"
        "Graceful shutdown successful for" = "Cierre controlado exitoso para"
        "Graceful shutdown timed out for" = "Tiempo de espera agotado para el cierre controlado de"
        "Graceful shutdown failed for" = "El cierre controlado falló para"
        "Force termination successful for" = "Terminación forzada exitosa para"
        "Force termination failed for" = "La terminación forzada falló para"
        "App hotkey toggled for" = "Tecla de acceso rápido de la aplicación alternada para"
        "Warning: App not defined" = "Advertencia: Aplicación no definida"
        "Configuration validation passed" = "Validación de configuración exitosa"
        "Configuration validation failed" = "Falló la validación de configuración"
        "Authentication required" = "Se requiere autenticación"
        "OBS authentication failed" = "Falló la autenticación de OBS"
        "OBS authentication successful" = "Autenticación de OBS exitosa"
        "OBS connection error" = "Error de conexión de OBS"
        "OBS replay buffer started" = "Buffer de repetición OBS iniciado"
        "Replay buffer start error" = "Error al iniciar el buffer de repetición"
        "OBS replay buffer stopped" = "Buffer de repetición OBS detenido"
        "Replay buffer stop error" = "Error al detener el buffer de repetición"
        "OBS is already running" = "OBS ya está en ejecución"
        "Starting OBS" = "Iniciando OBS"
        "OBS startup complete" = "Inicio de OBS completado"
        "OBS startup failed" = "Falló el inicio de OBS"
        "WebSocket receive error" = "Error de recepción WebSocket"
        "Failed to connect to OBS" = "No se pudo conectar a OBS"
        "Connected to OBS WebSocket" = "Conectado al WebSocket de OBS"
        "Error receiving Hello message" = "Error al recibir el mensaje Hello"
    }
}

Write-Host "Este script ayuda a identificar textos no traducidos."
Write-Host "Por favor, ejecute este script y luego use las herramientas de traducción apropiadas para completar las traducciones."
Write-Host ""
Write-Host "Archivo de mensajes: $messagesPath"
Write-Host ""

# Count untranslated keys for each language
$languages = @("ru", "fr", "es", "pt-BR", "id-ID")
foreach ($lang in $languages) {
    $englishPattern = "[A-Z][a-z]+\s+[a-z]+"  # Simple pattern to detect English text
    $untranslatedCount = 0

    $messages.$lang.PSObject.Properties | ForEach-Object {
        if ($_.Value -match $englishPattern -and $_.Value -notmatch "[А-Яа-я]|[À-ÿ]|[ÁÉÍÓÚáéíóú]|[ÃÕãõ]|[A-Za-z]{1,2}\s*:") {
            $untranslatedCount++
        }
    }

    Write-Host "Language: $lang - Approx. untranslated keys: $untranslatedCount"
}

Write-Host ""
Write-Host "翻訳が必要なキーの概数を表示しました。"
Write-Host "完全な翻訳を行うには、プロの翻訳サービスまたはネイティブスピーカーに依頼することを推奨します。"
