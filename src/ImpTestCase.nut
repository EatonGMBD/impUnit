// MIT License
//
// Copyright 2016 Electric Imp
//
// SPDX-License-Identifier: MIT
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO
// EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES
// OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
// ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
// OTHER DEALINGS IN THE SOFTWARE.

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
   * Output an info message
   * @param {*=""} message
   */
  function info(message = "") {
    this.runner.log(
        ImpUnitMessage(ImpUnitMessageTypes.info, {
          "message": message
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
   * @param {number|*} expected
   * @param {number|*} actual
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
   * @param {number|*} expected
   * @param {number|*} actual
   * @param {number|*} maxDiff
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
   * @param {*} value1
   * @param {*} value2
   * @param {string} message
   * @param {boolean} isForwardPass - on forward pass value1 is treated "expected", value2 as "actual" and vice-versa on backward pass
   * @param {string} path - current slot path
   * @param {int} level - current depth level
   * @private
   */
  function _assertDeepEqual(value1, value2, message, equalityFunction, isForwardPass, path = "", level = 0) {
    local cleanPath = @(p) p.len() == 0 ? p : p.slice(1);

    if (level > 32) {
      throw "Possible cyclic reference at " + cleanPath(path);
    }

    if (typeof value1 != typeof value2) {
      throw format("Values are not the same type, typeof lhs = %s, typeof rhs = %s", typeof value1, typeof value2)
    }

    switch (type(value1)) {
      case "table":
      case "class":
      case "array":

        foreach (k, v in value1) {
          local extendedPath = path + "." + k;

          if (!(k in value2)) {
            throw format(message, cleanPath(extendedPath),
              isForwardPass ? v + "" : "none",
              isForwardPass ? "none" : v + "");
          }

          this._assertDeepEqual(value1[k], value2[k], message, equalityFunction, isForwardPass, extendedPath, level + 1);
        }

        break;

      case "instance":
        if(equalityFunction != null && type(equalityFunction) == "function") {
          local equal = equalityFunction(value1, value2);
          if(!equal) {
              throw format(message, cleanPath(path), value1 + "", value2 + "");
          }
        } else {
            if (value2 != value1) {
              throw format(message, cleanPath(path), value1 + "", value2 + "");
            }
        }

        break;

      case "meta":

        switch(typeof value1) {
          case "blob":

            if (value1.len() != value2.len()) {
              throw format("Blob lengths unequal, lhs.len() == %d, rhs.len() == %d", value1.len(), value2.len());
            }

            if (crypto.equals(value1, value2) == false) {
              throw format("Blobs are the same length (%d bytes), but the contents are not identical.", value1.len());
            }

            break;

          default:

            if (value2 != value1) {
              throw format(message, cleanPath(path), value1 + "", value2 + "");
            }

            break;
        }

        break;

      case "null":
        break;

      default:
        if (value2 != value1) {
          throw format(message, cleanPath(path), value1 + "", value2 + "");
        }

        break;
    }
  }

  /**
   * Perform a deep comparison of two values
   * Useful for comparing arrays or tables
   * @param {*} expected
   * @param {*} actual
   * @param {string} message
   */
  function assertDeepEqual(expected, actual, message = "Comparison failed on '%s': expected %s, got %s", equalityFunction = null) {
    this.assertions++;
    this._assertDeepEqual(expected, actual, message, equalityFunction, true); // forward pass
    this._assertDeepEqual(actual, expected, message, equalityFunction, false); // backwards pass
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
