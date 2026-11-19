package io.tesobe;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;
import java.util.stream.Stream;
import org.junit.jupiter.api.Test;

/**
 * Checks the contract between the Keycloak provider and OBP-API, without a server.
 *
 * <p>obp-api-contract/contract.json lists every OBP-API call the provider makes, with the response fields it reads.
 * obp-api-contract/snapshot.json is what an OBP-API documents for those calls. snapshot.py writes it.
 */
class ObpApiContractTest {

    private static final ObjectMapper JSON = new ObjectMapper();
    private static final Path ROOT = Paths.get("").toAbsolutePath();
    private static final Path CONTRACT_DIR = ROOT.resolve("obp-api-contract");

    private static JsonNode load(String name) throws IOException {
        return JSON.readTree(Files.readAllBytes(CONTRACT_DIR.resolve(name)));
    }

    private static String read(String relative) throws IOException {
        return new String(Files.readAllBytes(ROOT.resolve(relative)), StandardCharsets.UTF_8);
    }

    private static List<JsonNode> calls() throws IOException {
        List<JsonNode> out = new ArrayList<>();
        load("contract.json").get("calls").forEach(out::add);
        return out;
    }

    private static List<JsonNode> snapshot() throws IOException {
        List<JsonNode> out = new ArrayList<>();
        load("snapshot.json").get("endpoints").forEach(out::add);
        return out;
    }

    private static String key(JsonNode call) {
        return call.get("verb").asText() + " " + call.get("path").asText();
    }

    private static List<String> strings(JsonNode node, String field) {
        List<String> out = new ArrayList<>();
        if (node.has(field)) node.get(field).forEach(n -> out.add(n.asText()));
        return out;
    }

    private static JsonNode snapshotOf(JsonNode call) throws IOException {
        for (JsonNode entry : snapshot()) if (key(entry).equals(key(call))) return entry;
        return null;
    }

    /** Whether a line of Java builds the path of an OBP-API call: it is code, not a comment, and it names /obp/ in a string. */
    static boolean buildsObpPath(String line) {
        String code = line.trim();
        if (code.startsWith("//") || code.startsWith("*") || code.startsWith("/*")) return false;
        return code.contains("\"/obp/") || code.contains("/obp/\"");
    }

    /** The lines of the provider's own source that build an OBP-API path: "file:line text". */
    private static List<String[]> obpPathLines() throws IOException {
        List<String[]> out = new ArrayList<>();
        List<Path> files;
        try (Stream<Path> walk = Files.walk(ROOT.resolve("src/main/java"))) {
            files = walk.filter(p -> p.toString().endsWith(".java")).sorted().collect(Collectors.toList());
        }
        for (Path file : files) {
            String relative = ROOT.relativize(file).toString();
            String[] lines = read(relative).split("\n", -1);
            for (int i = 0; i < lines.length; i++) {
                if (buildsObpPath(lines[i])) out.add(new String[] {relative, String.valueOf(i + 1), lines[i]});
            }
        }
        return out;
    }

    @Test
    void everyCallInTheContractIsInItsSourceFile() throws IOException {
        List<String> gone = new ArrayList<>();
        for (JsonNode call : calls()) {
            String text = read(call.get("source").asText());
            for (String needle : strings(call, "needles")) {
                if (!text.contains(needle)) gone.add(key(call) + ": " + needle);
            }
        }
        assertEquals(List.of(), gone);
    }

    @Test
    void everyObpApiPathInTheSourceIsAListedCall() throws IOException {
        List<JsonNode> listed = calls();
        List<String> unlisted = new ArrayList<>();
        for (String[] line : obpPathLines()) {
            boolean covered = listed.stream().anyMatch(c ->
                    c.get("source").asText().equals(line[0])
                            && strings(c, "needles").stream().anyMatch(n -> line[2].contains(n)));
            if (!covered) unlisted.add(line[0] + ":" + line[1] + " " + line[2].trim());
        }
        assertEquals(List.of(), unlisted);
    }

    @Test
    void theSnapshotWasTakenForThisContract() throws IOException {
        Set<String> contract = calls().stream().map(ObpApiContractTest::key).collect(Collectors.toSet());
        Set<String> snap = snapshot().stream().map(ObpApiContractTest::key).collect(Collectors.toSet());
        assertEquals(contract, snap);
    }

    @Test
    void everyCallReachesAnEndpointObpApiDocuments() throws IOException {
        List<String> undocumented = new ArrayList<>();
        for (JsonNode call : calls()) {
            JsonNode entry = snapshotOf(call);
            if (entry == null || entry.path("missing").asBoolean(false)) undocumented.add(key(call));
        }
        assertEquals(List.of(), undocumented);
    }

    @Test
    void everyFieldTheCodeReadsIsDocumentedUnlessTheContractSaysItIsNot() throws IOException {
        List<String> problems = new ArrayList<>();
        for (JsonNode call : calls()) {
            JsonNode entry = snapshotOf(call);
            if (entry == null) continue;
            Set<String> documented = new HashSet<>(strings(entry, "fields"));
            List<String> accepted = strings(call, "undocumented_fields");
            for (String read : strings(call, "reads")) {
                if (!isDocumented(read, documented) && !accepted.contains(read)) {
                    problems.add(key(call) + ": " + read + " is not documented");
                }
            }
        }
        assertEquals(List.of(), problems);
    }

    @Test
    void aFieldIsLeftOutOfUndocumentedFieldsOnceObpApiDocumentsIt() throws IOException {
        List<String> documentedNow = new ArrayList<>();
        for (JsonNode call : calls()) {
            JsonNode entry = snapshotOf(call);
            if (entry == null) continue;
            Set<String> documented = new HashSet<>(strings(entry, "fields"));
            for (String field : strings(call, "undocumented_fields")) {
                if (isDocumented(field, documented)) {
                    documentedNow.add(key(call) + ": " + field + " is documented now; remove it from undocumented_fields");
                }
            }
        }
        assertEquals(List.of(), documentedNow);
    }

    @Test
    void everyUndocumentedFieldIsAlsoRead() throws IOException {
        List<String> stray = new ArrayList<>();
        for (JsonNode call : calls()) {
            for (String field : strings(call, "undocumented_fields")) {
                if (!strings(call, "reads").contains(field)) stray.add(key(call) + ": " + field);
            }
        }
        assertEquals(List.of(), stray);
    }

    /** A read written a|b is documented when either name is. */
    static boolean isDocumented(String read, Set<String> documented) {
        return Arrays.stream(read.split("\\|")).anyMatch(documented::contains);
    }

    @Test
    void theCoverageScanSeesAPathPutTogetherFromPiecesAndSkipsComments() {
        assertTrue(buildsObpPath("String path = \"/obp/v6.0.0/users/provider/\" + encode(p);"));
        assertTrue(buildsObpPath("String url = base + \"/obp/\" + version + \"/users\";"));
        assertFalse(buildsObpPath("     * GET /obp/v6.0.0/users/{USER_ID}"));
        assertFalse(buildsObpPath("// GET \"/obp/v6.0.0/users\""));
        assertFalse(buildsObpPath("String x = \"users\";"));
    }

    @Test
    void aReadWithAlternativesNeedsOnlyOneOfThemDocumented() {
        Set<String> documented = Set.of("first_name");
        assertTrue(isDocumented("first_name|firstname", documented));
        assertFalse(isDocumented("last_name|lastname", documented));
    }
}
