package io.tesobe;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.List;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.util.stream.Collectors;
import java.util.stream.Stream;
import org.junit.jupiter.api.Test;

/**
 * Every OBP-API path the provider and its documents name uses version v5.1.0 or newer. A deployment can then switch
 * the older versions off without breaking the provider, and no reader is sent to a URL that no longer answers.
 */
class ObpApiVersionTest {

    private static final Path ROOT = Paths.get("").toAbsolutePath();
    private static final Pattern VERSION = Pattern.compile("obp/v(\\d+)\\.(\\d+)\\.(\\d+)(?![\\w.])");
    private static final List<String> EXTENSIONS =
            List.of(".java", ".md", ".json", ".yml", ".yaml", ".properties", ".sh", ".sample", ".example");
    private static final Set<String> SKIPPED = Set.of("target", ".git", "node_modules", "themes");

    /** The versions below v5.1.0 that a line names in an OBP-API path, as vX.Y.Z. */
    static List<String> versionsBelow510(String line) {
        List<String> found = new ArrayList<>();
        Matcher m = VERSION.matcher(line);
        while (m.find()) {
            int major = Integer.parseInt(m.group(1));
            int minor = Integer.parseInt(m.group(2));
            int patch = Integer.parseInt(m.group(3));
            boolean below = major < 5 || (major == 5 && (minor < 1));
            if (below) found.add("v" + major + "." + minor + "." + patch);
        }
        return found;
    }

    private static List<Path> files() throws IOException {
        try (Stream<Path> walk = Files.walk(ROOT)) {
            return walk.filter(Files::isRegularFile)
                    .filter(p -> {
                        for (Path part : ROOT.relativize(p)) if (SKIPPED.contains(part.toString())) return false;
                        return true;
                    })
                    .filter(p -> EXTENSIONS.stream().anyMatch(e -> p.toString().endsWith(e)))
                    .filter(p -> !ROOT.relativize(p).toString().equals("obp-api-contract/snapshot.json"))
                    // This file spells old versions out on purpose, to test the check.
                    .filter(p -> !p.getFileName().toString().equals("ObpApiVersionTest.java"))
                    .sorted()
                    .collect(Collectors.toList());
        }
    }

    @Test
    void theFilesAreFound() throws IOException {
        // So an empty result below means "no old version", not "no files".
        assertTrue(files().size() > 5, "found " + files().size() + " files");
    }

    @Test
    void everyObpApiPathUsesV510OrNewer() throws IOException {
        List<String> old = new ArrayList<>();
        for (Path file : files()) {
            String[] lines = new String(Files.readAllBytes(file), StandardCharsets.UTF_8).split("\n", -1);
            for (int i = 0; i < lines.length; i++) {
                for (String version : versionsBelow510(lines[i])) {
                    old.add(ROOT.relativize(file) + ":" + (i + 1) + " " + version);
                }
            }
        }
        assertEquals(List.of(), old);
    }

    @Test
    void theCheckSeesAVersionBelowV510HoweverThePathIsWritten() {
        assertEquals(List.of("v2.2.0"), versionsBelow510("GET /obp/v2.2.0/message-docs/x"));
        assertEquals(List.of("v5.0.0"), versionsBelow510("\"/obp/v5.0.0/banks\""));
        assertEquals(List.of("v4.0.0", "v1.2.1"), versionsBelow510("a /obp/v4.0.0/x and /obp/v1.2.1/y"));
    }

    @Test
    void theCheckLeavesV510AndNewerAlone() {
        assertEquals(List.of(), versionsBelow510("/obp/v5.1.0/root"));
        assertEquals(List.of(), versionsBelow510("/obp/v6.0.0/users"));
        assertEquals(List.of(), versionsBelow510("/obp/v10.0.0/x"));
        assertEquals(List.of(), versionsBelow510("version 4.0.0 of the document"));
    }
}
