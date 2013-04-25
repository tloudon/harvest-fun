#!/bin/bash

ruby obrien.rb  | mutt -s '[DAILY HARVEST REPORT]' -- test@example.com
