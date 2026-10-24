package dev.useunion.union_analytics

import android.annotation.SuppressLint
import dev.useunion.Environment
import dev.useunion.FeatureRole
import dev.useunion.LogLevel
import dev.useunion.ManagedFrame
import dev.useunion.PrivacyMode
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

@SuppressLint("RestrictedApi")
internal class ArgumentsTest {
    @Test
    fun propertiesKeepStringNumberBoolAndDropTheRest() {
        val p = Arguments.properties(
            mapOf(
                "plan" to "pro",
                "minutes" to 30,
                "big" to 5_000_000_000L,
                "ratio" to 0.5,
                "on" to true,
                "nan" to Double.NaN,
                "inf" to Double.POSITIVE_INFINITY,
                "list" to listOf(1, 2),
                "null" to null,
                7 to "non-string key",
            ),
        )
        assertEquals(
            mapOf<String, Any>("plan" to "pro", "minutes" to 30, "big" to 5_000_000_000L, "ratio" to 0.5, "on" to true),
            p,
        )
    }

    @Test
    fun propertiesFromGarbageIsEmpty() {
        assertTrue(Arguments.properties(null).isEmpty())
        assertTrue(Arguments.properties("nope").isEmpty())
    }

    @Test
    fun traitsKeepOnlyStrings() {
        assertEquals(mapOf("plan" to "pro"), Arguments.traits(mapOf("plan" to "pro", "n" to 1)))
    }

    @Test
    fun privacyModeRoleEnvironmentLogLevel() {
        assertEquals(PrivacyMode.StrictAnonymous, Arguments.privacyMode("strict_anonymous"))
        assertEquals(PrivacyMode.ProductAnalytics, Arguments.privacyMode("product_analytics"))
        assertNull(Arguments.privacyMode("other"))
        assertEquals(FeatureRole.Success, Arguments.featureRole("success"))
        assertEquals(FeatureRole.Discovery, Arguments.featureRole("discovery"))
        assertNull(Arguments.featureRole("bogus"))
        assertEquals(Environment.Testflight, Arguments.environment("testflight"))
        assertNull(Arguments.environment(null))
        assertEquals(LogLevel.Debug, Arguments.logLevel("debug"))
        assertEquals(LogLevel.None, Arguments.logLevel("none"))
    }

    @Test
    fun options() {
        val o = Arguments.options(
            mapOf(
                "environment" to "testflight",
                "logLevel" to "debug",
                "crashReporting" to false,
                "hangDetection" to false,
                "inAppPackages" to listOf("my_app", 3),
            ),
        )
        assertEquals(Environment.Testflight, o.environment)
        assertEquals(LogLevel.Debug, o.logLevel)
        assertFalse(o.crashReporting)
        assertFalse(o.hangDetection)
        assertFalse(o.automaticScreenTracking)
        assertEquals(listOf("my_app"), o.inAppPackages)
    }

    @Test
    fun optionsDefaultsWhenMissing() {
        val o = Arguments.options(mapOf("environment" to null, "logLevel" to null))
        assertNull(o.environment)
        assertEquals(LogLevel.Warning, o.logLevel)
        assertTrue(o.crashReporting)
        assertTrue(o.hangDetection)
        assertFalse(o.automaticScreenTracking)
    }

    @Test
    fun frames() {
        val frames = Arguments.frames(
            listOf(
                mapOf("function" to "main", "module" to "my_app", "file" to "package:my_app/main.dart", "line" to 10, "column" to 5, "inApp" to true),
                mapOf("function" to "_rootRun", "module" to null, "file" to null, "line" to null, "column" to null, "inApp" to false),
                mapOf("file" to "no_function.dart"),
            ),
        )
        assertEquals(2, frames.size)
        assertEquals(ManagedFrame("main", "my_app", "package:my_app/main.dart", 10, 5, true), frames[0])
        assertEquals(ManagedFrame("_rootRun", null, null, null, null, false), frames[1])
    }
}
