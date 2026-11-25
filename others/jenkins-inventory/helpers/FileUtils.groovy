package helpers

import groovy.json.JsonSlurper
import org.yaml.snakeyaml.Yaml

/**
 * Utility class for reading and parsing JSON/YAML files from the Jenkins workspace.
 *
 * Usage:
 *   import helpers.FileUtils
 *
 *   def config = FileUtils.fetchAndParseJSON(this, out, 'config/projects.json')
 *   def manifest = FileUtils.fetchAndParseYAML(this, out, 'config/manifest.yaml')
 **/

class FileUtils {

    /**
     * Read and parse a JSON file from the workspace.
     *
     * @param dslFactory  The Job DSL script context (pass `this`).
     * @param out         The output stream for logging (pass `out`).
     * @param path        Path to the JSON file, relative to the workspace root.
     * @return            Parsed object (Map, List, etc.) or null on failure.
     */
    static Object fetchAndParseJSON(def dslFactory, def out, String path) {
        try {
            def content = dslFactory.readFileFromWorkspace(path)
            out.println("FileUtils: successfully read JSON from '${path}'")
            return new JsonSlurper().parseText(content)
        } catch (Exception e) {
            out.println("FileUtils: failed to parse JSON from '${path}': ${e.message}")
            throw e
        }
    }

    /**
     * Read and parse a YAML file from the workspace.
     *
     * @param dslFactory  The Job DSL script context (pass `this`).
     * @param out         The output stream for logging (pass `out`).
     * @param path        Path to the YAML file, relative to the workspace root.
     * @return            Parsed object (Map, List, etc.) or null on failure.
     */
    static Object fetchAndParseYAML(def dslFactory, def out, String path) {
        try {
            def content = dslFactory.readFileFromWorkspace(path)
            out.println("FileUtils: successfully read YAML from '${path}'")
            return new Yaml().load(content)
        } catch (Exception e) {
            out.println("FileUtils: failed to parse YAML from '${path}': ${e.message}")
            throw e
        }
    }
}