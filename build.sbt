import sbt.Keys.libraryDependencies

ThisBuild / organization := "ru.neoflex.ndk"
ThisBuild / scalaVersion := "2.12.16"

lazy val root = (project in file("."))
  .settings(
    publish / skip := true,
    name := "nf-flink-functions",
    libraryDependencies += "org.apache.flink" %% "flink-table-api-scala" % "1.15.2"
  )

