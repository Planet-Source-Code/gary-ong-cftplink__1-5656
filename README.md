<div align="center">

## CFTPLink


</div>

### Description

This is a class that provides a simple interface for FTP uploading functionality. It is based on code submitted by Philipp 'Schlaubi' Stern and Kristian Trenskow. The code can be easily extended to provide other FTP functionality. Also included is an example of how to use it.
 
### More Info
 
At a minimum set the Server, username and password properties before calling the AddFilesToSend method and finally the SendFiles method.

It's reasonably well documented, but you may have to refer to FTP doco to fully understand it. Uses the Microsoft Winsock control 6.0.

AddFilesToSend returns True if it has been added ok, false if the file doesn't exist. SendFiles returns -1 if the server or username has not been set or else the number of files successfully sent.


<span>             |<span>
---                |---
**Submitted On**   |2000-01-24 21:39:00
**By**             |[Gary Ong](https://github.com/Planet-Source-Code/PSCIndex/blob/master/ByAuthor/gary-ong.md)
**Level**          |Advanced
**User Rating**    |4.7 (56 globes from 12 users)
**Compatibility**  |VB 5\.0, VB 6\.0
**Category**       |[Internet/ HTML](https://github.com/Planet-Source-Code/PSCIndex/blob/master/ByCategory/internet-html__1-34.md)
**World**          |[Visual Basic](https://github.com/Planet-Source-Code/PSCIndex/blob/master/ByWorld/visual-basic.md)
**Archive File**   |[CODE\_UPLOAD30261242000\.zip](https://github.com/Planet-Source-Code/gary-ong-cftplink__1-5656/archive/master.zip)








