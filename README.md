# Dynamic OSD Application List
 Allows for the dynamic installation of applications during a MDT task sequence.
 
Run the Update-MDTApplicationXML.ps1 and provide the path to the Applications.xml within the control folder inside the MDT deployment share.

This will make the application object specific adjustments to support the script that runs during the task sequence. It is totally safe and will not cause disruptive issues.

Updates the MDT Applications.xml file to support the functionality built into the Invoke-OSDApplicationList.ps1 powershell script.

Just refresh the 'Applications' view within the MDT Deployment Workbench after executing this script and make any application specific adjustments as needed.

Sort the application(s) by the version column within the MDT Deployment Workbench to see the order in which the applications would be installed by the task sequence.
	  

Updates the 'Version' property of each application with the installation order (Will be based on creation date initially, but can be adjusted according to any specific needs.
Updates the 'Language' property of each application within the Applications.xml with a powershell based condition that will determine if the application will be installed during a task sequence.

To install in all cases, just simply use "$True" without the quotes.
To skip in all cases, just simply use "$False" without the quotes.

Setting the right mixture of condition and installation order will provide a super smooth and consistent installation experience.

Example: VMWare Tools
 
Installation Order = 1

Condition = ($ComputerSystem.Manufacturer -imatch '.*VM.*Ware.*')

This would ensure that VMWare Tools gets installed first only VMWare virtual machines.

Any variable that will be available during the execution of the Invoke-OSDApplicationList.ps1 powershell script can be used within a condition.

Dynamically creates 'MandatoryApplicationXXX' task sequence variables with the GUIDs of MDT application objects to install on a device during operating system deployment.
          
Individual applications or entire application folders can be disabled to exclude the application(s) from being considered by the script during deployment.

Application(s) that have already been installed by the task sequence whose GUID is stored within a 'InstalledApplicationsXXX' variable will be skipped if this script is executed multiple times during a task sequence.