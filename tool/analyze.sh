#!/bin/bash

cd ..

cd flat_orm
flutter analyze
cd ..

cd flat_annotation
dart analyze --fatal-infos --fatal-warnings .
cd ..

cd flat_generator
dart analyze --fatal-infos --fatal-warnings .
cd ..

cd example
flutter analyze
