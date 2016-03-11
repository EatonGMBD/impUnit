/**
 * impUnit Test Framework
 *
 * @author Mikhail Yurasov <mikhail@electricimp.com>
 * @version 0.3.0
 * @package ImpUnit
 */

// libs required by impUnit

/**
 * JSON encoder
 *
 * @author Mikhail Yurasov <mikhail@electricimp.com>
 * @verion 0.4.0-impUnit
 *
 *  impUnit chages:
 *   - packaging as module
 */
function __module_ImpUnit_JSONEncoder() {
  local exports = class {

    static version = [0, 4, 0];

    // max structure depth
    // anything above probably has a cyclic ref
    static _maxDepth = 32;

    /**
     * Encode value to JSON
     * @param {table|array|*} value
     * @returns {string}
     */
    function encode(value) {
      return this._encode(value);
    }

    /**
     * @param {table|array} val
     * @param {integer=0} depth – current depth level
     * @private
     */
    function _encode(val, depth = 0) {

      // detect cyclic reference
      if (depth > this._maxDepth) {
        throw "Possible cyclic reference";
      }

      local
        r = "",
        s = "",
        i = 0;

      switch (typeof val) {

        case "table":
        case "class":
          s = "";

          // serialize properties, but not functions
          foreach (k, v in val) {
            if (typeof v != "function") {
              s += ",\"" + k + "\":" + this._encode(v, depth + 1);
            }
          }

          s = s.len() > 0 ? s.slice(1) : s;
          r += "{" + s + "}";
          break;

        case "array":
          s = "";

          for (i = 0; i < val.len(); i++) {
            s += "," + this._encode(val[i], depth + 1);
          }

          s = (i > 0) ? s.slice(1) : s;
          r += "[" + s + "]";
          break;

        case "integer":
        case "float":
        case "bool":
          r += val;
          break;

        case "null":
          r += "null";
          break;

        case "instance":

          if ("_serialize" in val && typeof val._serialize == "function") {

            // serialize instances by calling _serialize method
            r += this._encode(val._serialize(), depth + 1);

          } else {

            s = "";

            try {

              // iterate through instances which implement _nexti meta-method
              foreach (k, v in val) {
                s += ",\"" + k + "\":" + this._encode(v, depth + 1);
              }

            } catch (e) {

              // iterate through instances w/o _nexti
              // serialize properties, but not functions
              foreach (k, v in val.getclass()) {
                if (typeof v != "function") {
                  s += ",\"" + k + "\":" + this._encode(val[k], depth + 1);
                }
              }

            }

            s = s.len() > 0 ? s.slice(1) : s;
            r += "{" + s + "}";
          }

          break;

        // strings and all other
        default:
          r += "\"" + this._escape(val.tostring()) + "\"";
          break;
      }

      return r;
    }

    /**
     * Escape strings according to http://www.json.org/ spec
     * @param {string} str
     */
    function _escape(str) {
      local res = "";

      for (local i = 0; i < str.len(); i++) {

        local ch1 = (str[i] & 0xFF);

        if ((ch1 & 0x80) == 0x00) {
          // 7-bit Ascii

          ch1 = format("%c", ch1);

          if (ch1 == "\"") {
            res += "\\\"";
          } else if (ch1 == "\\") {
            res += "\\\\";
          } else if (ch1 == "/") {
            res += "\\/";
          } else if (ch1 == "\b") {
            res += "\\b";
          } else if (ch1 == "\f") {
            res += "\\f";
          } else if (ch1 == "\n") {
            res += "\\n";
          } else if (ch1 == "\r") {
            res += "\\r";
          } else if (ch1 == "\t") {
            res += "\\t";
          } else {
            res += ch1;
          }

        } else {

          if ((ch1 & 0xE0) == 0xC0) {
            // 110xxxxx = 2-byte unicode
            local ch2 = (str[++i] & 0xFF);
            res += format("%c%c", ch1, ch2);
          } else if ((ch1 & 0xF0) == 0xE0) {
            // 1110xxxx = 3-byte unicode
            local ch2 = (str[++i] & 0xFF);
            local ch3 = (str[++i] & 0xFF);
            res += format("%c%c%c", ch1, ch2, ch3);
          } else if ((ch1 & 0xF8) == 0xF0) {
            // 11110xxx = 4 byte unicode
            local ch2 = (str[++i] & 0xFF);
            local ch3 = (str[++i] & 0xFF);
            local ch4 = (str[++i] & 0xFF);
            res += format("%c%c%c%c", ch1, ch2, ch3, ch4);
          }

        }
      }

      return res;
    }
  }

  return exports;
}

/**
 * Promise class for Squirrel (Electric Imp)
 * This file is licensed under the MIT License
 *
 * Initial version: 08-12-2015
 *
 * @see https://www.promisejs.org/implementing/
 *
 * @copyright (c) 2015 SMS Diagnostics Pty Ltd
 * @author Aron Steg
 * @author Mikhail Yurasov <mikhail@electricimp.com>
 * @version 1.1.0-impUnit
 *
 *  impUnit chages:
 *   - packaging as module
 *   - isPendinng()
 */
function __module_ImpUnit_Promise() {

  local exports = {};

  exports = class {

      static version = [1, 1, 0];

      _state = null;
      _value = null;
      _handlers = null;

      constructor(fn) {

          const PROMISE_STATE_PENDING = 0;
          const PROMISE_STATE_FULFILLED = 1;
          const PROMISE_STATE_REJECTED = 2;

          _state = PROMISE_STATE_PENDING;
          _handlers = [];
          _doResolve(fn, _resolve, _reject);
      }

      // **** Private functions ****

      function _fulfill(result) {
          _state = PROMISE_STATE_FULFILLED;
          _value = result;
          foreach (handler in _handlers) {
              _handle(handler);
          }
          _handlers = null;
      }

      function _reject(error) {
          _state = PROMISE_STATE_REJECTED;
          _value = error;
          foreach (handler in _handlers) {
              _handle(handler);
          }
          _handlers = null;
      }

      function _resolve(result) {
          try {
              local then = _getThen(result);
              if (then) {
                  _doResolve(then.bindenv(result), _resolve, _reject);
                  return;
              }
              _fulfill(result);
          } catch (e) {
              _reject(e);
          }
      }

     /**
      * Check if a value is a Promise and, if it is,
      * return the `then` method of that promise.
      *
      * @param {Promise|*} value
      * @return {function|null}
      */
      function _getThen(value) {

          if (
              // detect that the value is some form of Promise
              // by the fact it has .then() method
              (typeof value == "instance")
              && ("then" in value)
              && (typeof value.then == "function")
            ) {
              return value.then;
          }

          return null;
      }

      function _doResolve(fn, onFulfilled, onRejected) {
          local done = false;
          try {
              fn(
                  function (value = null /* allow resolving without argument */) {
                      if (done) return;
                      done = true;
                      onFulfilled(value)
                  }.bindenv(this),

                  function (reason = null /* allow rejection without argument */) {
                      if (done) return;
                      done = true;
                      onRejected(reason)
                  }.bindenv(this)
              )
          } catch (ex) {
              if (done) return;
              done = true;
              onRejected(ex);
          }
      }

      function _handle(handler) {
          if (_state == PROMISE_STATE_PENDING) {
              _handlers.push(handler);
          } else {
              if (_state == PROMISE_STATE_FULFILLED && typeof handler.onFulfilled == "function") {
                  handler.onFulfilled(_value);
              }
              if (_state == PROMISE_STATE_REJECTED && typeof handler.onRejected == "function") {
                  handler.onRejected(_value);
              }
          }
      }

      // **** Public functions ****

      /**
       * Execute handler once the Promise is resolved/rejected
       * @param {function|null} onFulfilled
       * @param {function|null} onRejected
       */
      function then(onFulfilled = null, onRejected = null) {
          // ensure we are always asynchronous
          imp.wakeup(0, function () {
              _handle({ onFulfilled=onFulfilled, onRejected=onRejected });
          }.bindenv(this));

          return this;
      }

      /**
       * Execute handler on failure
       * @param {function|null} onRejected
       */
      function fail(onRejected = null) {
          return then(null, onRejected);
      }

      /**
       * Execute handler both on success and failure
       * @param {function|null} always
       */
      function finally(always = null) {
        return then(always, always);
      }

      // impUnit additions

      function isPending() {
        return this._state == PROMISE_STATE_PENDING;
      }
  }

  return exports;
}

// impUnit module

function __module_impUnit(Promise, JSONEncoder) {
/**
 * Message handling
 * @package ImpUnit
 */

// message types
local ImpUnitMessageTypes = {
  sessionStart = "SESSION_START", // session start
  testStart = "TEST_START", // test start
  testOk = "TEST_OK", // test success
  testFail = "TEST_FAIL", // test failure
  sessionResult = "SESSION_RESULT", // session result
  debug = "DEBUG", // debug message
  externalCommand = "EXTERNAL_COMMAND" // external command
}

/**
 * Test message
 */
local ImpUnitMessage = class {

  type = "";
  message = "";
  session = "";

  /**
   * @param {ImpUnitMessageTypes} type - Message type
   * @param {string} message - Message
   */
  constructor(type, message = "") {
    this.type = type;
    this.message = message;
  }

  /**
   * Convert message to JSON
   */
  function toJSON() {
    return JSONEncoder.encode({
      __IMPUNIT__ = 1,
      type = this.type,
      session = this.session,
      message = this.message
    });
  }

  /**
   * Convert to human-readable string
   */
  function toString() {
    return "[impUnit:" + this.type + "] "
      + (typeof this.message == "string"
          ? this.message
          : JSONEncoder.encode(this.message)
        );
  }
}
/**
 * Base for test cases
 * @package ImpUnit
 */
local ImpTestCase = class {

  runner = null; // runner instance
  session = null; // session name
  assertions = 0;

  /**
   * Send message to impTest to execute external command
   * @param {string} command
   */
  function runCommand(command = "") {
    this.runner.log(
        ImpUnitMessage(ImpUnitMessageTypes.externalCommand, {
          "command": command
        })
    );
  }

  /**
   * Assert that something is true
   * @param {bool} condition
   * @param {string} message
   */
  function assertTrue(condition, message = "Failed to assert that condition is true") {
    this.assertions++;
    if (!condition) {
      throw message;
    }
  }

  /**
   * Assert that two values are equal
   * @param {bool} condition
   * @param {string} message
   */
   function assertEqual(expected, actual, message = "Expected value: %s, got: %s") {
    this.assertions++;
    if (expected != actual) {
      throw format(message, expected + "", actual + "");
    }
  }

  /**
   * Assert that value is greater than something
   * @param {number|*} actual
   * @param {number|*} cmp
   * @param {string} message
   */
   function assertGreater(actual, cmp, message = "Failed to assert that %s > %s") {
    this.assertions++;
    if (actual <= cmp) {
      throw format(message, actual + "", cmp + "");
    }
  }

  /**
   * Assert that value is less than something
   * @param {number|*} actual
   * @param {number|*} cmp
   * @param {string} message
   */
   function assertLess(actual, cmp, message = "Failed to assert that %s < %s") {
    this.assertions++;
    if (actual >= cmp) {
      throw format(message, actual + "", cmp + "");
    }
  }

  /**
   * Assert that two values are within a certain range
   * @param {bool} condition
   * @param {string} message
   */
  function assertClose(expected, actual, maxDiff, message = "Expected value: %s±%s, got: %s") {
    this.assertions++;
    if (math.abs(expected - actual) > maxDiff) {
      throw format(message, expected + "", maxDiff + "", actual + "");
    }
  }

  /**
   * Perform a deep comparison of two values
   * Useful for comparing arrays or tables
   * @param {*} expected
   * @param {*} actual
   * @param {string} message
   */
  function assertDeepEqual(expected, actual, message = "At [%s]: expected \"%s\", got \"%s\"", path = "", level = 0) {

    if (0 == level) {
      this.assertions++;
    }

    local cleanPath = @(p) p.len() == 0 ? p : p.slice(1);

    if (level > 32) {
      throw "Possible cyclic reference at " + cleanPath(path);
    }

    switch (type(actual)) {
      case "table":
      case "class":
      case "array":

        foreach (k, v in expected) {

          path += "." + k;

          if (!(k in actual)) {
            throw format("Missing slot [%s] in actual value", cleanPath(path));
          }

          this.assertDeepEqual(expected[k], actual[k], message, path, level + 1);
        }

        break;

      case "null":
        break;

      default:
        if (expected != actual) {
          throw format(message, cleanPath(path), expected + "", actual + "");
        }

        break;
    }
  }

  /**
   * Assert that the value is between min amd max
   * @param {number|*} actual
   * @param {number|*} min
   * @param {number|*} max
   */
  function assertBetween(actual, min, max, message = "Expected value the range of %s..%s, got %s") {
    this.assertions++;

    // swap min/max if min > max
    if (min > max) {
      local t = max;
      max = min;
      min = t;
    }

    if (actual < min || actual > max) {
      throw format(message, min + "", max + "", actual + "");
    }
  }

  /**
   * Assert that function throws an erorr
   * @param {function} fn
   * @param {table|userdata|class|instance|meta} ctx
   * @param {array} args - arguments for the function
   * @param {string} message
   * @return {error} error thrown by function
   */
  function assertThrowsError(fn, ctx, args = [], message = "Function was expected to throw an error") {
    this.assertions++;
    args.insert(0, ctx)

    try {
      fn.pacall(args);
    } catch (e) {
      return e;
    }

    throw message;
  }
}
/**
 * Test runner
 * @package ImpUnit
 */

/**
 * Imp test runner
 */
local ImpUnitRunner = class {

  // options
  timeout = 2;
  readableOutput = true;
  stopOnFailure = false;
  session = null;

  // result
  tests = 0;
  assertions = 0;
  failures = 0;

  _testsGenerator = null;

  /**
   * Run tests
   */
  function run() {
    this.log(ImpUnitMessage(ImpUnitMessageTypes.sessionStart))
    this._testsGenerator = this._createTestsGenerator();
    this._run();
  }

  /**
   * Log message
   * @param {ImpUnitMessage} message
   * @private
   */
  function log(message) {
    // set session id
    message.session = this.session;

    if (this.readableOutput) {
      server.log(message.toString() /* use custom conversion method to avoid stack resizing limitations on metamethods */)
    } else {
      server.log(message.toJSON());
    }
  }

  /**
   * Find test cases and methods
   */
  function _findTests() {

    local testCases = {};

    foreach (rootKey, rootValue in getroottable()) {
      if (type(rootValue) == "class" && rootValue.getbase() == ImpTestCase) {

        local testCaseName = rootKey;
        local testCaseClass = rootValue;

        testCases[testCaseName] <- {
          setUp = ("setUp" in testCaseClass),
          tearDown = ("tearDown" in testCaseClass),
          tests = []
        };

        // find test methoids
        foreach (memberKey, memberValue in testCaseClass) {
          if (memberKey.len() >= 4 && memberKey.slice(0, 4) == "test") {
            testCases[testCaseName].tests.push(memberKey);
          }
        }

        // sort test methods
        testCases[testCaseName].tests.sort();
      }
    }

    // [debug]
    this.log(ImpUnitMessage(ImpUnitMessageTypes.debug, {"testCasesFound": testCases}));

    return testCases;
  }

  /**
   * Create a generator that yields tests (test methods)
   * @return {Generator}
   * @private
   */
  function _createTestsGenerator() {

    local testCases = this._findTests();

    foreach (testCaseName, testCase in testCases) {

      local testCaseInstance = getroottable()[testCaseName]();
      testCaseInstance.session = this.session;
      testCaseInstance.runner = this;

      if (testCase.setUp) {
        this.log(ImpUnitMessage(ImpUnitMessageTypes.testStart, testCaseName + "::setUp()"));
        yield {
          "case" : testCaseInstance,
          "method" : testCaseInstance.setUp.bindenv(testCaseInstance)
        };
      }

      for (local i = 0; i < testCase.tests.len(); i++) {
        this.tests++;
        this.log(ImpUnitMessage(ImpUnitMessageTypes.testStart, testCaseName + "::" +  testCase.tests[i] + "()"));
        yield {
          "case" : testCaseInstance,
          "method" : testCaseInstance[testCase.tests[i]].bindenv(testCaseInstance)
        };
      }

      if (testCase.tearDown) {
        this.log(ImpUnitMessage(ImpUnitMessageTypes.testStart, testCaseName + "::tearDown()"));
        yield {
          "case" : testCaseInstance,
          "method" : testCaseInstance.tearDown.bindenv(testCaseInstance)
        };
      }
    }

    return null;
  }

  /**
   * We're done
   * @private
   */
  function _finish() {
    // log result message
    this.log(ImpUnitMessage(ImpUnitMessageTypes.sessionResult, {
      tests = this.tests,
      assertions = this.assertions,
      failures = this.failures
    }));
  }

  /**
   * Called when test method is finished
   * @param {bool} success
   * @param {*} result - resolution/rejection argument
   * @param {integer} assertions - # of assettions made
   * @private
   */
  function _done(success, result, assertions = 0) {
      if (!success) {
        // log failure
        this.failures++;
        this.log(ImpUnitMessage(ImpUnitMessageTypes.testFail, result));
      } else {
        // log test method success
        this.log(ImpUnitMessage(ImpUnitMessageTypes.testOk, result));
      }

      // update assertions number
      this.assertions += assertions;

      // next
      if (!success && this.stopOnFailure) {
        this._finish();
      } else {
        this._run.bindenv(this)();
      }
  }

  function _now() {
    return "hardware" in getroottable()
      ? hardware.millis().tofloat() / 1000
      : time();
  }

  /**
   * Run tests
   * @private
   */
  function _run() {

    local test = resume this._testsGenerator;

    if (test) {

      // do GC before each run
      collectgarbage();

      test.assertions <- test["case"].assertions;
      test.result <- null;

      // record start time
      test.startedAt <- this._now();

      // run test method
      try {
        test.result = test.method();
      } catch (e) {
        // store sync test info
        test.error <- e;
      }

      // detect if test is async
      test.async <- test.result instanceof Promise;

      if (test.async) {

        // set the timeout timer

        test.timedOut <- false;

        test.timerId <- imp.wakeup(this.timeout, function () {
          if (test.result.isPending()) {
            test.timedOut = true;

            // update assertions counter to ignore assertions afrer the timeout
            test.assertions = test["case"].assertions;

            this._done(false, "Test timed out after " + this.timeout + "s");
          }
        }.bindenv(this));

        // handle result

        test.result

          // we're fine
          .then(function (message) {
            test.message <- message;
          })

          // we're screwed
          .fail(function (error) {
            test.error <- error;
          })

          // anyways...
          .finally(function(e) {

            // cancel timeout detection
            if (test.timerId) {
              imp.cancelwakeup(test.timerId);
              test.timerId = null;
            }

            if (!test.timedOut) {
              if ("error" in test) {
                this._done(false /* failure */, test.error, test["case"].assertions - test.assertions);
              } else {
                this._done(true /* success */, test.message, test["case"].assertions - test.assertions);
              }
            }

          }.bindenv(this));

      } else {
        // check timeout

        local testDuration = this._now() - test.startedAt;

        if (testDuration > this.timeout) {
          test.error <- "Test took " + testDuration + "s, longer than timeout of " + this.timeout + "s"
        }

        // test was sync
        if ("error" in test) {
          this._done(false /* failure */, test.error, test["case"].assertions - test.assertions);
        } else {
          this._done(true /* success */, test.result, test["case"].assertions - test.assertions);
        }
      }

    } else {
      this._finish();
    }
  }
}
  // export symbols
  return {
    "ImpTestCase" : ImpTestCase,
    "ImpUnitRunner" : ImpUnitRunner
  }
}

// impUnit bootstrapping

// resolve modules
__module_ImpUnit_Promise_exports <- __module_ImpUnit_Promise();
__module_ImpUnit_JSONEncoder_exports <- __module_ImpUnit_JSONEncoder();
__module_impUnit_exports <- __module_impUnit(__module_ImpUnit_Promise_exports, __module_ImpUnit_JSONEncoder_exports);

// add symbols from __module_impUnit to ::
ImpTestCase <- __module_impUnit_exports.ImpTestCase;
ImpUnitRunner <- __module_impUnit_exports.ImpUnitRunner;

// add Promise to ::
Promise <- __module_ImpUnit_Promise_exports;

