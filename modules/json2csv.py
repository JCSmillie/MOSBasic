#!/usr/local/munki/munki-python

# Python program to convert
# JSON file to CSV
 
 
import json
import csv
import sys

# Read the command-line argument passed to the interpreter when invoking the script
DataSubHeader = sys.argv[1]
JSON2Convert = sys.argv[2]
WriteCSVHere = sys.argv[3]
 
# Opening JSON file and loading the data
# into the variable data
with open(JSON2Convert, "r") as json_file:
    data = json.load(json_file)
 
 
devicestocsv = data[DataSubHeader] 

# now we will open a file for writing
data_file = open(WriteCSVHere, 'a')
 
# create the csv writer object
#csv_writer = csv.writer(data_file)
csv_writer = csv.writer(data_file, delimiter='\t')

 
# Counter variable used for writing
# headers to the CSV file
count = 0
 
for devi in devicestocsv:

    ##THIS CODE IS FOR OPENING THE FILE WITH A HEADER COLUMN
    ##NOT USING IT BUT KEEPING IN PLACE FOR REFERENCE.
    # if count == 0:
    #
    #     # Writing headers of CSV file
    #     header = devi.keys()
    #     csv_writer.writerow(header)
    #     count += 1
 
    # Writing data of CSV file
    csv_writer.writerow(devi.values())
 
data_file.close()