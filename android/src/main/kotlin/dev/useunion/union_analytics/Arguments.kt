package dev.useunion.union_analytics

import android.annotation.SuppressLint
import dev.useunion.Environment
import dev.useunion.FeatureRole
import dev.useunion.LogLevel
import dev.useunion.ManagedFrame
import dev.useunion.Options
import dev.useunion.PrivacyMode

/**
 * Maps method-channel arguments (what Flutter's standard codec decodes) to native Union types.
 * Pure functions with no Android dependency, so JUnit covers them on the JVM. Invalid input yields
 * null or is dropped, never an exception.
 */
internal object Arguments {
    fun string(args: Map<*, *>, key: String): String? = args[key] as? String

    fun bool(args: Map<*, *>, key: String): Boolean? = args[key] as? Boolean

    /** `String`, `Boolean`, finite `Number`. Anything else is dropped; the native SDK validates the rest. */
    fun properties(raw: Any?): Map<String, Any> {
        val map = raw as? Map<*, *> ?: return emptyMap()
        val out = LinkedHashMap<String, Any>()
        for ((k, v) in map) {
            val key = k as? String ?: continue
            when (v) {
                is String, is Boolean -> out[key] = v
                is Double -> if (v.isFinite()) out[key] = v
                is Float -> if (v.isFinite()) out[key] = v
                is Int, is Long -> out[key] = v
            }
        }
        return out
    }

    fun traits(raw: Any?): Map<String, String> {
        val map = raw as? Map<*, *> ?: return emptyMap()
        val out = LinkedHashMap<String, String>()
        for ((k, v) in map) {
            if (k is String && v is String) out[k] = v
        }
        return out
    }

    fun privacyMode(raw: String?): PrivacyMode? = when (raw) {
        "strict_anonymous" -> PrivacyMode.StrictAnonymous
        "product_analytics" -> PrivacyMode.ProductAnalytics
        else -> null
    }

    fun featureRole(raw: String?): FeatureRole? = when (raw) {
        "discovery" -> FeatureRole.Discovery
        "start" -> FeatureRole.Start
        "use" -> FeatureRole.Use
        "success" -> FeatureRole.Success
        "failure" -> FeatureRole.Failure
        else -> null
    }

    fun environment(raw: String?): Environment? = when (raw) {
        "development" -> Environment.Development
        "testflight" -> Environment.Testflight
        "production" -> Environment.Production
        else -> null
    }

    fun logLevel(raw: String?): LogLevel? = when (raw) {
        "debug" -> LogLevel.Debug
        "info" -> LogLevel.Info
        "warning" -> LogLevel.Warning
        "error" -> LogLevel.Error
        "none" -> LogLevel.None
        else -> null
    }

    fun options(raw: Any?): Options {
        val options = Options()
        val map = raw as? Map<*, *> ?: return options
        environment(map["environment"] as? String)?.let { options.environment = it }
        logLevel(map["logLevel"] as? String)?.let { options.logLevel = it }
        (map["crashReporting"] as? Boolean)?.let { options.crashReporting = it }
        (map["hangDetection"] as? Boolean)?.let { options.hangDetection = it }
        (map["inAppPackages"] as? List<*>)?.let { list ->
            options.inAppPackages = list.filterIsInstance<String>()
        }
        // Screens come from the Dart observer; the native tracker would only see the one FlutterActivity.
        options.automaticScreenTracking = false
        return options
    }

    private fun int(v: Any?): Int? = (v as? Number)?.toInt()

    @SuppressLint("RestrictedApi")
    fun frames(raw: Any?): List<ManagedFrame> {
        val list = raw as? List<*> ?: return emptyList()
        return list.mapNotNull { item ->
            val f = item as? Map<*, *> ?: return@mapNotNull null
            val function = f["function"] as? String ?: return@mapNotNull null
            ManagedFrame(
                function = function,
                module = f["module"] as? String,
                file = f["file"] as? String,
                line = int(f["line"]),
                column = int(f["column"]),
                inApp = f["inApp"] as? Boolean ?: false,
            )
        }
    }
}
