#!/bin/sh

#this code is tested un fresh 2015-11-21-raspbian-jessie-lite Raspberry Pi image
#by default this script should be located in two subdirecotries under the home

#sudo apt-get update -y && sudo apt-get upgrade -y
#sudo apt-get install git -y
#mkdir -p /home/pi/detect && cd /home/pi/detect
#git clone https://github.com/catonrug/vlc-detect.git && cd vlc-detect && chmod +x check.sh && ./check.sh

#check if script is located in /home direcotry
pwd | grep "^/home/" > /dev/null
if [ $? -ne 0 ]; then
  echo script must be located in /home direcotry
  return
fi

#it is highly recommended to place this directory in another directory
deep=$(pwd | sed "s/\//\n/g" | grep -v "^$" | wc -l)
if [ $deep -lt 4 ]; then
  echo please place this script in deeper directory
  return
fi

#set application name based on directory name
#this will be used for future temp directory, database name, google upload config, archiving
appname=$(pwd | sed "s/^.*\///g")

#set temp directory in variable based on application name
tmp=$(echo ../tmp/$appname)

#create temp directory
if [ ! -d "$tmp" ]; then
  mkdir -p "$tmp"
fi

#check if database directory has prepared 
if [ ! -d "../db" ]; then
  mkdir -p "../db"
fi

#set database variable
db=$(echo ../db/$appname.db)

#if database file do not exist then create one
if [ ! -f "$db" ]; then
  touch "$db"
fi

#check if google drive config directory has been made
#if the config file exists then use it to upload file in google drive
#if no config file is in the directory there no upload will happen
if [ ! -d "../gd" ]; then
  mkdir -p "../gd"
fi

name=$(echo "VLC Media Player")
base=$(echo "https://get.videolan.org/vlc/last")

architectures=$(cat <<EOF
win32
win64
extra line
EOF
)

wget -S --spider -o $tmp/output.log "$base/"

grep -A99 "^Resolving" $tmp/output.log | grep "HTTP.*200 OK"
if [ $? -eq 0 ]; then
#if file request retrieve http code 200 this means OK

printf %s "$architectures" | while IFS= read -r architecture
do {

filename=$(wget -qO- $base/$architecture/ | grep -v "$architecture\.exe\." | sed "s/exe/exe\n/g" | sed "s/\d034\|>/\n/g" | grep "$architecture\.exe" | head -1)

grep "$filename" $db > /dev/null
if [ $? -ne 0 ]; then
echo new version detected!

wget -S --spider -o $tmp/output.log $base/$architecture/$filename -q
url=$(sed "s/http/\nhttp/g" $tmp/output.log | sed "s/exe/exe\n/g" | grep "^http.*exe$")
echo $url

echo Downloading $filename
wget $url -O $tmp/$filename -q
echo

echo creating md5 checksum of file..
md5=$(md5sum $tmp/$filename | sed "s/\s.*//g")
echo

echo creating sha1 checksum of file..
sha1=$(sha1sum $tmp/$filename | sed "s/\s.*//g")
echo

version=$(echo "$filename" | sed "s/-/\n/g" | grep -v "[a-z]")

echo $version | grep "^[0-9]\+[\., ]\+[0-9]\+[\., ]\+[0-9]\+"
if [ $? -eq 0 ]; then
echo

echo "$filename">> $db
echo "$version">> $db
echo "$md5">> $db
echo "$sha1">> $db
echo >> $db

#if google drive config exists then upload and delete file:
if [ -f "../gd/$appname.cfg" ]
then
echo Uploading $filename to Google Drive..
echo Make sure you have created \"$appname\" directory inside it!
../uploader.py "../gd/$appname.cfg" "$tmp/$filename"
echo
fi

case "$architecture" in
win32)
bit=$(echo "(32-bit)")
;;
win64)
bit=$(echo "(64-bit)")
;;
esac

#lets send emails to all people in "posting" file
emails=$(cat ../posting | sed '$aend of file')
printf %s "$emails" | while IFS= read -r onemail
do {
python ../send-email.py "$onemail" "$name $version $bit" "$url 
https://4e7299a03ac49455dce684f7851a9aa3b33044ee.googledrive.com/host/0B_3uBwg3RcdVMFVpME1MdThxZ1U/$filename 
$md5
$sha1"
} done
echo

else
#version do not match version pattern
echo version do not match version pattern
emails=$(cat ../maintenance | sed '$aend of file')
printf %s "$emails" | while IFS= read -r onemail
do {
python ../send-email.py "$onemail" "To Do List" "Version do not match version pattern: 
$site "
} done
fi

else
#filename is already in database
echo filename is already in database
echo
fi

} done

else
#if http statis code is not 200 ok
emails=$(cat ../maintenance | sed '$aend of file')
printf %s "$emails" | while IFS= read -r onemail
do {
python ../send-email.py "$onemail" "To Do List" "the following link do not retrieve good http status code: 
$base"
} done
echo 
echo
fi



#clean and remove whole temp direcotry
rm $tmp -rf > /dev/null
