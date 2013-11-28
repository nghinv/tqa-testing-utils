#!/bin/bash  

#Created on 20Nov2013
#Author: QuyenNT

#Command to run this script:
# ./FileProcessor.sh yourPathToExceptionFile
#For ex: ./FileProcessor.sh /home/quyennt/Downloads/catalina.out.PERF_PLF_ENT_INTRANET_FORUM_READ_TOPIC 100000


#Path of Exception file. 
exceptionFilePath=$1
linesToProcess=$2

#method to check if a string contains a substring
# 0: contain
# 1: not contain
contains() {
    string="$1"
    substring="$2"
    if test "${string#*$substring}" != "$string"
    then
	#echo "Contain" #For testing only
        return 0    # $substring is in $string
    else
	#echo "Not Contain" #For testing only
        return 1    # $substring is not in $string
    fi
}

#Check if an element exists in an array
# 0: exists
# 1: no exists
array_contains() {
    local seeking=$1; shift
    local in=1
    for element; do
        if [[ $element == $seeking ]]; then
            in=0
            break
        fi
    done
    return $in
}

remove_duplicated_files(){
  workingFolder=$1
  #Find duplicated files by its size and delete
  #echo "Deleting duplicated files based on size....."
  declare -a fileSizeArr;
  fileSizeIndex=0;

  for entry in "$workingFolder"/*
    do
      #echo "$entry" #For testing only
      fileSize=$(stat -c%s "$entry")
      
      array_contains "$fileSize" "${fileSizeArr[@]}"
      arrayContainResult=$?
    
      #echo "file size="$fileSize #For testing only
      #echo "arrayContainResult="$arrayContainResult #For testing only
    
      if [ $arrayContainResult -eq 1 ]; then #if false
	fileSizeArr[fileSizeIndex]=$fileSize
	fileSizeIndex=$((fileSizeIndex+1)) 
      else #delete the file
	rm "$entry"
	echo "Removing $entry"
      fi  
  done
  return 0;
}


#Main
#echo "Start file processing....Start at:"
#date

sed -n "1,$linesToProcess p" $exceptionFilePath > ExceptionCutFile.txt 

#Get name of exception file input
exceptionFilename=$(basename "$exceptionFilePath")

echo "Extracting exceptions..."
#Cut all exceptions to another file
grep 'Exception\|at \|Caused by: ' ExceptionCutFile.txt > AllException_$exceptionFilename
allExceptionStack=AllException_$exceptionFilename

#Get all exceptions with line number
grep -n ".*Exception.*" $allExceptionStack | grep -v -E "(Caused by|[ \t]*at .*Exception)" > ExceptionLines.txt

#Get line number only
grep -Eo '^[^:]+' ExceptionLines.txt > ExceptionLineNumbers.txt



#An array to store exceptions
declare -a exceptionArr;
exceptionIndex=0;

#create template directory to save Exception stack files
mkdir -p "tmp"
tmpFolder=$(pwd)/tmp
fileNumber=0

if [ "$(ls -A $tmpFolder)" ]; then
  rm -r $tmpFolder/*.*
fi


#template file to save Exception stack
tmpFile=0;

IFS=$'\r\n' lineArr=($(cat ExceptionLineNumbers.txt))

#Array length
total=${#lineArr[*]}

echo "Writing Exception stack to file.....Start at:"
date
for (( i=0; i<=$(( $total -1 )); i++ ))
  do
    from=${lineArr[$i]}
    to=${lineArr[$i+1]}
    to=$((to-1))
    
    #echo "From:$from" 	#For testing only
    #echo "To:$to"	#For testing only
    
    #Write exception stack to file
    #echo "Writing Exception stack to file....."

    if [ $to -eq -1 ]; then
      #echo "To = -1"
      sed -n "$from,$linesToProcess p" $allExceptionStack > "$tmpFolder/$tmpFile".txt
    else  
      sed -n "$from,$to p" $allExceptionStack > "$tmpFolder/$tmpFile".txt
    fi  
    echo -e "\n\n-------------------------------------------------------------------\n\n" >> "$tmpFolder/$tmpFile".txt
      
    #echo "File $tmpFolder/$tmpFile.txt has been created"
    tmpFile=$((tmpFile+1)) 
    #End writing
    
    fileNumber=$((fileNumber+1)) 
    
    #Remove duplicated files every 100 files created
    #if [ $fileNumber -eq 100 ]; then 
      #echo "Remove method called"
    #  remove_duplicated_files      
     # fileNumber=0
    #fi    
done
echo "Writing exception to file....Stop at:"
date


echo "Geting uniq files....Start at:"
date

md5sum $tmpFolder/* > md5sumAllFiles.txt
#get md5 of file only
grep -Eo '^[^ ]+' md5sumAllFiles.txt > md5Values.txt

#get uniq value only
sort md5Values.txt | uniq > umd5.txt

#Pass to an array
IFS=$'\r\n' md5Arr=($(cat umd5.txt))
#Array length
total=${#md5Arr[*]}

mkdir -p "tmpUniq"
uniqTmpFolder=$(pwd)/tmpUniq

for (( i=0; i<=$(( $total -1 )); i++ ))
  do    
    md5Value=${md5Arr[$i]}   
    #Search and get the first value only
    line=$(grep "$md5Value" md5sumAllFiles.txt | head -1)
    #echo "Line:"$line
    fileName=$(basename $line)
    #echo $fileName
    
    #Copy uniq files to another place
    mv $tmpFolder/$fileName $uniqTmpFolder    
done
  
echo "Geting uniq files....Stop at:"
date

echo "Deleting duplicated files in uniq folder....Start at:"
date
remove_duplicated_files $uniqTmpFolder
echo "Deleting duplicated files in uniq folder....Stop at:"
date

#Combine all to one file
echo "Merging files...."
cat "$uniqTmpFolder"/*.txt > "ExceptionSummary_$exceptionFilename"
echo "Deleting template files"

rm -r $tmpFolder
rm -r $uniqTmpFolder
rm md5sumAllFiles.txt
rm md5Values.txt
rm umd5.txt
rm ExceptionCutFile.txt
rm $allExceptionStack
rm ExceptionLineNumbers.txt
rm ExceptionLines.txt

echo "Done!"
