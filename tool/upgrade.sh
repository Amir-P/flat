#!/bin/bash

cd ..

cd flat_orm
flutter packages pub upgrade
cd ..

cd flat_annotation
flutter packages pub upgrade
cd ..

cd flat_generator
flutter packages pub upgrade
cd ..

cd example
flutter packages pub upgrade
