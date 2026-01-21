#include "ruby.h"
#include "ruby/encoding.h"
#include <stdlib.h>
#include <string.h>

// Forward declarations
VALUE mArctic;

/*
 * Helper function to get environment variable count
 *
 * Iterates through the external environ array to count the total number
 * of environment variables currently set.
 *
 * @return [int] The number of environment variables
 */
static int env_count(void) {
    extern char **environ;
    char **env = environ;
    int count = 0;

    while (*env != NULL) {
        count++;
        env++;
    }

    return count;
}

/*
 * call-seq:
 *   Arctic[key] -> value or nil
 *
 * Retrieves the value of the environment variable +key+.
 *
 * Returns a frozen, deduplicated string via rb_enc_interned_str_cstr() for
 * memory efficiency. If the environment variable does not exist, returns +nil+.
 *
 * @param self [VALUE] The Arctic module
 * @param key [VALUE] A String containing the environment variable name
 * @return [VALUE] The frozen string value of the environment variable, or nil if not found
 *
 * Example:
 *   Arctic["PATH"]  #=> "/usr/bin:/bin"
 *   Arctic["NONE"]  #=> nil
 */
static VALUE arctic_aref(VALUE self, VALUE key) {
    const char* env_key;
    const char* env_value;

    Check_Type(key, T_STRING);
    env_key = StringValueCStr(key);
    env_value = getenv(env_key);

    if (env_value == NULL) {
        return Qnil;
    }

    return rb_enc_interned_str_cstr(env_value, rb_locale_encoding());
}

/*
 * call-seq:
 *   Arctic.fetch(key) -> value
 *   Arctic.fetch(key, default) -> value
 *   Arctic.fetch(key) {|key| block } -> value
 *
 * Retrieves the environment variable +key+.
 *
 * If the key exists, returns its frozen, deduplicated value.
 * If the key does not exist:
 * - With a block: yields the key to the block and returns the block's result
 * - With a default argument: returns the default value
 * - Without either: raises KeyError
 *
 * @param argc [int] The number of arguments passed
 * @param argv [VALUE*] Array of arguments (key and optional default)
 * @param self [VALUE] The Arctic module
 * @return [VALUE] The environment variable value, default value, or block result
 * @raise [KeyError] If the key is not found and no default or block is provided
 *
 * Example:
 *   Arctic.fetch("PATH")                    #=> "/usr/bin:/bin"
 *   Arctic.fetch("MISSING", "default")      #=> "default"
 *   Arctic.fetch("MISSING") { |k| "#{k}?" } #=> "MISSING?"
 *   Arctic.fetch("MISSING")                 #=> raises KeyError
 */
static VALUE arctic_fetch(int argc, VALUE *argv, VALUE self) {
    VALUE key, default_value;
    const char* env_key;
    const char* env_value;

    rb_scan_args(argc, argv, "11", &key, &default_value);
    Check_Type(key, T_STRING);

    env_key = StringValueCStr(key);
    env_value = getenv(env_key);

    if (env_value == NULL) {
        if (rb_block_given_p()) {
            return rb_yield(key);
        } else if (argc == 2) {
            return default_value;
        } else {
            rb_raise(rb_eKeyError, "key not found: \"%s\"", env_key);
        }
    }

    return rb_enc_interned_str_cstr(env_value, rb_locale_encoding());
}

/*
 * call-seq:
 *   Arctic.key?(key) -> true or false
 *   Arctic.has_key?(key) -> true or false
 *   Arctic.include?(key) -> true or false
 *   Arctic.member?(key) -> true or false
 *
 * Returns +true+ if the environment variable +key+ exists, +false+ otherwise.
 *
 * This method has multiple aliases following Ruby's ENV API conventions.
 *
 * @param self [VALUE] The Arctic module
 * @param key [VALUE] A String containing the environment variable name
 * @return [VALUE] Qtrue if the key exists, Qfalse otherwise
 *
 * Example:
 *   Arctic.key?("PATH")    #=> true
 *   Arctic.has_key?("XYZ") #=> false
 */
static VALUE arctic_has_key(VALUE self, VALUE key) {
    const char* env_key;

    Check_Type(key, T_STRING);
    env_key = StringValueCStr(key);

    return getenv(env_key) != NULL ? Qtrue : Qfalse;
}

/*
 * call-seq:
 *   Arctic.each {|key, value| block } -> Arctic
 *   Arctic.each -> Enumerator
 *   Arctic.each_pair {|key, value| block } -> Arctic
 *   Arctic.each_pair -> Enumerator
 *
 * Iterates over all environment variables.
 *
 * When called with a block, yields each environment variable as a [key, value]
 * pair where both key and value are frozen, deduplicated strings. Returns Arctic.
 *
 * When called without a block, returns an Enumerator.
 *
 * @param self [VALUE] The Arctic module
 * @return [VALUE] Arctic module (when block given) or Enumerator (when no block)
 * @yield [key, value] Gives each environment variable name and value
 *
 * Example:
 *   Arctic.each { |key, value| puts "#{key}=#{value}" }
 *   Arctic.each.first(5)  #=> [["HOME", "/Users/..."], ...]
 */
static VALUE arctic_each(VALUE self) {
    extern char **environ;
    char **env = environ;

    RETURN_SIZED_ENUMERATOR(self, 0, 0, env_count);

    while (*env != NULL) {
        char *entry = *env;
        char *sep = strchr(entry, '=');

        if (sep != NULL) {
            VALUE key = rb_enc_interned_str(entry, sep - entry, rb_locale_encoding());
            VALUE val = rb_enc_interned_str_cstr(sep + 1, rb_locale_encoding());
            rb_yield_values(2, key, val);
        }

        env++;
    }

    return self;
}

/*
 * call-seq:
 *   Arctic.keys -> Array
 *
 * Returns an array containing all environment variable names.
 *
 * Each key is a frozen, deduplicated string for memory efficiency.
 *
 * @param self [VALUE] The Arctic module
 * @return [VALUE] An Array of frozen String keys
 *
 * Example:
 *   Arctic.keys  #=> ["HOME", "PATH", "USER", ...]
 */
static VALUE arctic_keys(VALUE self) {
    extern char **environ;
    char **env = environ;
    VALUE ary = rb_ary_new();

    while (*env != NULL) {
        char *entry = *env;
        char *sep = strchr(entry, '=');

        if (sep != NULL) {
            VALUE key = rb_enc_interned_str(entry, sep - entry, rb_locale_encoding());
            rb_ary_push(ary, key);
        }

        env++;
    }

    return ary;
}

/*
 * call-seq:
 *   Arctic.values -> Array
 *
 * Returns an array containing all environment variable values.
 *
 * Each value is a frozen, deduplicated string for memory efficiency.
 *
 * @param self [VALUE] The Arctic module
 * @return [VALUE] An Array of frozen String values
 *
 * Example:
 *   Arctic.values  #=> ["/Users/...", "/usr/bin:/bin", "username", ...]
 */
static VALUE arctic_values(VALUE self) {
    extern char **environ;
    char **env = environ;
    VALUE ary = rb_ary_new();

    while (*env != NULL) {
        char *entry = *env;
        char *sep = strchr(entry, '=');

        if (sep != NULL) {
            VALUE val = rb_enc_interned_str_cstr(sep + 1, rb_locale_encoding());
            rb_ary_push(ary, val);
        }

        env++;
    }

    return ary;
}

/*
 * call-seq:
 *   Arctic.to_h -> Hash
 *
 * Returns a Hash containing all environment variables.
 *
 * Both keys and values are frozen, deduplicated strings for memory efficiency.
 *
 * @param self [VALUE] The Arctic module
 * @return [VALUE] A Hash mapping environment variable names to their values
 *
 * Example:
 *   Arctic.to_h  #=> {"HOME"=>"/Users/...", "PATH"=>"/usr/bin:/bin", ...}
 */
static VALUE arctic_to_h(VALUE self) {
    extern char **environ;
    char **env = environ;
    VALUE hash = rb_hash_new();

    while (*env != NULL) {
        char *entry = *env;
        char *sep = strchr(entry, '=');

        if (sep != NULL) {
            VALUE key = rb_enc_interned_str(entry, sep - entry, rb_locale_encoding());
            VALUE val = rb_enc_interned_str_cstr(sep + 1, rb_locale_encoding());
            rb_hash_aset(hash, key, val);
        }

        env++;
    }

    return hash;
}

/*
 * call-seq:
 *   Arctic.to_hash -> Hash
 *
 * Alias for Arctic.to_h.
 *
 * Returns a Hash containing all environment variables with frozen,
 * deduplicated keys and values.
 *
 * @param self [VALUE] The Arctic module
 * @return [VALUE] A Hash mapping environment variable names to their values
 *
 * @see arctic_to_h
 */
static VALUE arctic_to_hash(VALUE self) {
    return arctic_to_h(self);
}

/*
 * call-seq:
 *   Arctic.empty? -> true or false
 *
 * Returns +true+ if the environment contains no variables, +false+ otherwise.
 *
 * This is a fast check that only examines the first element of the environ array.
 *
 * @param self [VALUE] The Arctic module
 * @return [VALUE] Qtrue if environment is empty, Qfalse otherwise
 *
 * Example:
 *   Arctic.empty?  #=> false (typically)
 */
static VALUE arctic_empty_p(VALUE self) {
    extern char **environ;
    return environ[0] == NULL ? Qtrue : Qfalse;
}

/*
 * call-seq:
 *   Arctic.size -> Integer
 *   Arctic.length -> Integer
 *
 * Returns the number of environment variables.
 *
 * This method is aliased as both +size+ and +length+ for compatibility with
 * Ruby collection conventions.
 *
 * @param self [VALUE] The Arctic module
 * @return [VALUE] An Integer representing the count of environment variables
 *
 * Example:
 *   Arctic.size    #=> 42
 *   Arctic.length  #=> 42
 */
static VALUE arctic_size(VALUE self) {
    return INT2NUM(env_count());
}

/*
 * call-seq:
 *   Arctic.inspect -> String
 *
 * Returns a string representation of the Arctic module.
 *
 * The format is "#<Arctic:0x...>" where the hex value is the module's memory address.
 *
 * @param self [VALUE] The Arctic module
 * @return [VALUE] A String containing the inspection representation
 *
 * Example:
 *   Arctic.inspect  #=> "#<Arctic:0x00007f8b1c000000>"
 */
static VALUE arctic_inspect(VALUE self) {
    return rb_sprintf("#<Arctic:%p>", (void*)self);
}

/*
 * Document-module: Arctic
 *
 * Arctic provides a read-only, memory-efficient interface to environment variables.
 *
 * Arctic is designed as a drop-in replacement for Ruby's ENV that prioritizes memory
 * efficiency through aggressive string deduplication. All strings returned by Arctic
 * are frozen and interned using rb_enc_interned_str_cstr(), which means repeated
 * accesses to the same environment variable will return the exact same String object
 * in memory rather than creating new allocations.
 *
 * == Key Features
 *
 * * *Read-only access*: Arctic only provides methods for reading environment variables,
 *   preventing accidental modifications to the environment.
 * * *Memory efficient*: All returned strings are frozen and deduplicated, dramatically
 *   reducing memory usage when environment variables are accessed multiple times.
 * * *ENV-compatible API*: Implements the most commonly-used read-only methods from Ruby's
 *   ENV, making it easy to switch between the two.
 * * *Fast*: Direct C implementation with minimal overhead.
 *
 * == Usage
 *
 *   # Basic access
 *   Arctic["PATH"]        #=> "/usr/bin:/bin"
 *   Arctic["MISSING"]     #=> nil
 *
 *   # Fetch with defaults or blocks
 *   Arctic.fetch("HOME")                    #=> "/Users/username"
 *   Arctic.fetch("MISSING", "default")      #=> "default"
 *   Arctic.fetch("MISSING") { |k| "#{k}?" } #=> "MISSING?"
 *
 *   # Existence checks
 *   Arctic.key?("PATH")     #=> true
 *   Arctic.has_key?("XYZ")  #=> false
 *
 *   # Iteration
 *   Arctic.each { |k, v| puts "#{k}=#{v}" }
 *   Arctic.keys             #=> ["HOME", "PATH", "USER", ...]
 *   Arctic.values           #=> ["/Users/...", "/usr/bin:/bin", ...]
 *
 *   # Conversion
 *   Arctic.to_h             #=> {"HOME"=>"/Users/...", "PATH"=>...}
 *
 *   # Information
 *   Arctic.size             #=> 42
 *   Arctic.empty?           #=> false
 *
 * == Memory Efficiency
 *
 * Consider a typical Rails application that might access ENV["RAILS_ENV"] hundreds
 * or thousands of times during initialization. With standard ENV, each access creates
 * a new String object. With Arctic, all accesses return the exact same frozen String
 * object, using only a single allocation regardless of how many times it's accessed.
 *
 * This is especially valuable in large applications with many environment variables
 * or in long-running processes that frequently access configuration from the environment.
 *
 * == Comparison with ENV
 *
 * Arctic implements the following ENV methods:
 * - Arctic[] (like ENV[])
 * - Arctic.fetch (like ENV.fetch)
 * - Arctic.key?, has_key?, include?, member? (like ENV.key? etc.)
 * - Arctic.each, each_pair (like ENV.each)
 * - Arctic.keys, values (like ENV.keys, ENV.values)
 * - Arctic.to_h, to_hash (like ENV.to_h)
 * - Arctic.empty?, size, length (like ENV.empty?, ENV.size)
 *
 * Arctic does NOT implement write operations like []=, store, update, delete, clear, etc.
 * For modifying the environment, continue using ENV.
 *
 * @see https://docs.ruby-lang.org/en/master/ENV.html ENV documentation for comparison
 */

/*
 * Initializes the Arctic extension.
 *
 * This function is called by Ruby when the extension is loaded. It defines
 * the Arctic module and registers all its singleton methods.
 *
 * The Arctic module provides a read-only, memory-efficient interface to
 * environment variables, using frozen and deduplicated strings throughout.
 *
 * Registered methods include:
 * - Core access: [], fetch
 * - Existence checks: key?, has_key?, include?, member?
 * - Iteration: each, each_pair
 * - Conversion: keys, values, to_h, to_hash
 * - Information: empty?, size, length
 * - Utility: inspect
 */
void Init_arctic(void) {
    mArctic = rb_define_module("Arctic");

    // Core access methods
    rb_define_singleton_method(mArctic, "[]", arctic_aref, 1);
    rb_define_singleton_method(mArctic, "fetch", arctic_fetch, -1);

    // Existence checks (multiple aliases per ENV API)
    rb_define_singleton_method(mArctic, "key?", arctic_has_key, 1);
    rb_define_singleton_method(mArctic, "has_key?", arctic_has_key, 1);
    rb_define_singleton_method(mArctic, "include?", arctic_has_key, 1);
    rb_define_singleton_method(mArctic, "member?", arctic_has_key, 1);

    // Iteration
    rb_define_singleton_method(mArctic, "each", arctic_each, 0);
    rb_define_singleton_method(mArctic, "each_pair", arctic_each, 0);

    // Conversion methods
    rb_define_singleton_method(mArctic, "keys", arctic_keys, 0);
    rb_define_singleton_method(mArctic, "values", arctic_values, 0);
    rb_define_singleton_method(mArctic, "to_h", arctic_to_h, 0);
    rb_define_singleton_method(mArctic, "to_hash", arctic_to_hash, 0);

    // Info methods
    rb_define_singleton_method(mArctic, "empty?", arctic_empty_p, 0);
    rb_define_singleton_method(mArctic, "size", arctic_size, 0);
    rb_define_singleton_method(mArctic, "length", arctic_size, 0);

    // Utility methods
    rb_define_singleton_method(mArctic, "inspect", arctic_inspect, 0);
}
