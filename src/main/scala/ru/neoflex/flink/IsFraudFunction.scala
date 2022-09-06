package ru.neoflex.flink

import org.apache.flink.table.functions.ScalarFunction

class IsFraudFunction extends ScalarFunction {
  def eval(txnsNum: Long): String = if (txnsNum > 5) "FRAUD" else "OK"
}
