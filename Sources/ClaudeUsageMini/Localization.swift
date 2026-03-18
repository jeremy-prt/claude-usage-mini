import Foundation

enum Lang: String, CaseIterable, Sendable {
    case en, fr

    var label: String {
        switch self {
        case .en: "English"
        case .fr: "Français"
        }
    }
}

@MainActor
func L(_ key: String) -> String {
    let lang = Lang(rawValue: UserDefaults.standard.string(forKey: "appLanguage") ?? "en") ?? .en
    return strings[lang]?[key] ?? key
}

nonisolated func Lsync(_ key: String) -> String {
    let lang = Lang(rawValue: UserDefaults.standard.string(forKey: "appLanguage") ?? "en") ?? .en
    return strings[lang]?[key] ?? key
}

private let strings: [Lang: [String: String]] = [
    .en: [
        // Popover
        "claude_usage": "Claude Usage",
        "sign_in_prompt": "Sign in to view your usage.",
        "sign_in_button": "Sign in with Claude",
        "quit": "Quit",
        "session_5h": "5h Session",
        "session_7d": "7d Session",
        "per_model_7d": "Per-model (7d)",
        "extra_usage": "Extra Usage",
        "context_window": "Context Window",
        "no_active_session": "No active session detected",
        "updated_ago": "Updated %@ ago",
        "reset_in": "Resets in %@",
        "before_compact": "%d%% until compact",
        "compact_imminent": "Compact imminent",
        "paste_code": "Paste the code from your browser:",
        "paste_placeholder": "Paste your token here...",
        "cancel": "Cancel",
        "submit": "Submit",

        // Settings
        "general": "General",
        "launch_at_login": "Launch at Login",
        "install_for_login": "Install in Applications to manage launch at login.",
        "login_update_failed": "Could not update launch at login.",
        "polling_interval": "Refresh interval",
        "polling_footer": "Minimum 15 min — below that the Anthropic API applies rate limiting.",
        "appearance": "Appearance",
        "menubar_icon": "Menu bar icon",
        "icon_bars": "Bars 5h/7d",
        "icon_logo": "Claude icon",
        "icon_both": "Icon + Bars",
        "monochrome": "Monochrome mode",
        "monochrome_desc": "Disables colors for a clean, uniform look.",
        "language": "Language",
        "context_section": "Context Window",
        "show_context": "Show context window usage",
        "context_refresh": "Context refresh",
        "context_footer": "Reads local Claude Code session files to estimate context window fill.",
        "account": "Account",
        "sign_out": "Sign Out",

        // Hotkey
        "hotkey_section": "Shortcut",
        "hotkey_toggle": "Toggle panel",
        "hotkey_recording": "Press a key combo...",
        "hotkey_none": "Not set",
        "hotkey_record": "Record",
        "hotkey_clear": "Clear",
        "hotkey_recording_short": "Press...",
        "hotkey_define": "Set",

        // Notifications
        "notifications": "Notifications",
        "notif_enabled": "Enable notifications",
        "notif_threshold_5h": "5h session threshold",
        "notif_threshold_7d": "7d session threshold",
        "notif_test": "Test",
        "notif_test_title": "Claude Usage Mini",
        "notif_test_body": "Notifications are working!",
        "notif_title_5h": "5h session usage",
        "notif_title_7d": "7d session usage",
        "notif_body": "Usage reached %d%%",
        "notif_footer": "You will be notified when usage exceeds the set threshold.",

        // Right-click menu
        "settings": "Settings...",
        "disconnect": "Sign Out",

        // Errors
        "oauth_error": "OAuth error — try again",
        "no_oauth_flow": "No pending OAuth flow",
        "token_exchange_failed": "Token exchange failed",
        "invalid_response": "Invalid server response",
        "auth_error": "Authentication error",
        "not_signed_in": "Not signed in",
        "rate_limited": "Rate limited — interval increased",
        "session_expired": "Session expired — please sign in again",
        "token_refresh_failed": "Token refresh failed — will retry",
    ],
    .fr: [
        // Popover
        "claude_usage": "Claude Usage",
        "sign_in_prompt": "Connectez-vous pour voir votre utilisation.",
        "sign_in_button": "Se connecter avec Claude",
        "quit": "Quitter",
        "session_5h": "Session 5h",
        "session_7d": "Session 7j",
        "per_model_7d": "Par modèle (7j)",
        "extra_usage": "Usage supplémentaire",
        "context_window": "Fenêtre de contexte",
        "no_active_session": "Aucune session active détectée",
        "updated_ago": "Mis à jour il y a %@",
        "reset_in": "Réinitialisation dans %@",
        "before_compact": "%d%% avant compactage",
        "compact_imminent": "Compactage imminent",
        "paste_code": "Collez le code depuis votre navigateur :",
        "paste_placeholder": "Collez votre token ici...",
        "cancel": "Annuler",
        "submit": "Valider",

        // Settings
        "general": "Général",
        "launch_at_login": "Lancer au démarrage",
        "install_for_login": "Installez dans Applications pour gérer le lancement au démarrage.",
        "login_update_failed": "Impossible de modifier le lancement au démarrage.",
        "polling_interval": "Intervalle de rafraîchissement",
        "polling_footer": "Minimum 15 min — en dessous l'API Anthropic applique un rate limit.",
        "appearance": "Apparence",
        "menubar_icon": "Icône dans la barre de menu",
        "icon_bars": "Barres 5h/7j",
        "icon_logo": "Icône Claude",
        "icon_both": "Icône + Barres",
        "monochrome": "Mode monochrome",
        "monochrome_desc": "Désactive les couleurs pour un affichage sobre et uniforme.",
        "language": "Langue",
        "context_section": "Fenêtre de contexte",
        "show_context": "Afficher l'utilisation du contexte",
        "context_refresh": "Rafraîchissement contexte",
        "context_footer": "Lit les fichiers de session locale de Claude Code pour estimer le remplissage de la fenêtre de contexte.",
        "account": "Compte",
        "sign_out": "Se déconnecter",

        // Hotkey
        "hotkey_section": "Raccourci",
        "hotkey_toggle": "Afficher/masquer le panneau",
        "hotkey_recording": "Appuyez sur une combinaison...",
        "hotkey_none": "Non défini",
        "hotkey_record": "Enregistrer",
        "hotkey_clear": "Supprimer",
        "hotkey_recording_short": "Appuyez...",
        "hotkey_define": "Définir",

        // Notifications
        "notifications": "Notifications",
        "notif_enabled": "Activer les notifications",
        "notif_threshold_5h": "Seuil session 5h",
        "notif_threshold_7d": "Seuil session 7j",
        "notif_test": "Tester",
        "notif_test_title": "Claude Usage Mini",
        "notif_test_body": "Les notifications fonctionnent !",
        "notif_title_5h": "Session 5h",
        "notif_title_7d": "Session 7j",
        "notif_body": "Utilisation à %d%%",
        "notif_footer": "Vous serez notifié quand l'utilisation dépasse le seuil défini.",

        // Right-click menu
        "settings": "Réglages...",
        "disconnect": "Se déconnecter",

        // Errors
        "oauth_error": "Erreur OAuth — réessayez",
        "no_oauth_flow": "Aucun flux OAuth en cours",
        "token_exchange_failed": "Échange de token échoué",
        "invalid_response": "Réponse du serveur invalide",
        "auth_error": "Erreur d'authentification",
        "not_signed_in": "Non connecté",
        "rate_limited": "Limité par l'API — intervalle augmenté",
        "session_expired": "Session expirée — reconnectez-vous",
        "token_refresh_failed": "Échec du rafraîchissement — nouvelle tentative",
    ],
]
