*** Settings ***
Documentation       Orders robots from RobotSpareBin Industries Inc.
...                 Saves the order HTML receipt as a PDF file.
...                 Saves the screenshot of the ordered robot.
...                 Embeds the screenshot of the robot to the PDF receipt.
...                 Creates ZIP archive of the receipts and the images.
...                 Reading secrets from the vault.

Library             RPA.Browser.Selenium    auto_close=${FALSE}
Library             RPA.HTTP
Library             RPA.Tables
Library             RPA.Excel.Files
Library             RPA.PDF
Library             RPA.Desktop
Library             RPA.RobotLogListener
Library             String
Library             RPA.Database
Library             Dialogs
Library             RPA.Windows
Library             RPA.Archive
Library             RPA.FileSystem
Library             RPA.Dialogs
Library             RPA.FTP
Library             RPA.Robocorp.Vault


*** Variables ***
${CSV_FILE}
${test1}
${PDF_TEMP_OUTPUT_DIRECTORY}    ${CURDIR}${/}temp
${OUTPUT_DIRECTORY}             ${CURDIR}${/}output


*** Tasks ***
Order robots from RobotSpareBin Industries Inc
    Open the robot order website
    Read CSV File and Process all Robots
    Close Multiple PDFs
    Create ZIP package from PDF files
    Close the browser
    Cleanup temporary PDF directory


*** Keywords ***
#Collect CSV file from the user
 #    Add heading    Upload CSV File
 #    Add file input
 #    ...    label=Upload the CSV file with Robots data
 #    ...    name=fileupload
 #    ...    file_type=Excel files (*.xls;*.xlsx;*.csv)
 #    ...    destination=${OUTPUT_DIR}
 #    ${response}    Run dialog
 #    RETURN    ${response.fileupload}[0]

Open the robot order website
    Open Available Browser    https://robotsparebinindustries.com/#/robot-order
    Maximize Browser Window

Read CSV File and Process all Robots
    # Download the CSV file
    rpa.http.Download    https://robotsparebinindustries.com/orders.csv    overwrite=True
    # Read Vault Secret that contains name and path of the CSV file downloaded
    ${secret}    Get Secret    credentials
    @{orders}    Read table from CSV    ${secret}[CSVFile]    header=True
    #Process all Robots using the data from the CSV file
    FOR    ${order}    IN    @{orders}
        Wait Until Element Is Visible    class:alert-buttons    timeout=5
        Click Button    OK
        # Select the Head
        Select From List By Index    xpath=//select[@id="head"]    ${order}[Head]
        # Select the Body
        Select Radio Button    body    ${order}[Body]
        # Fill the part number for Legs
        Input Text    xpath=//Input[@placeholder='Enter the part number for the legs']    ${order}[Legs]
        # Fill the Address
        Input Text    xpath=//Input[@name='address']    ${order}[Address]
        Click Button    preview
        Wait Until Element Is Visible    id:robot-preview-image    timeout=5
        Sleep    2s
        Click Button    order
        ${test1}    Set Variable    ${0}
        # Catch web exceptions
        WHILE    ${test1} < 1
            TRY
                Wait Until Element Is Visible    id:receipt    timeout=5
            EXCEPT
                Click Button    order
            ELSE
                ${test1}    Evaluate    ${test1} + 1
                ${receipt}    Get Element Attribute    id:receipt    outerHTML
                # Create receipt PDF file
                Html To Pdf
                ...    ${receipt}
                ...    ${PDF_TEMP_OUTPUT_DIRECTORY}${/}${order}[Order number].pdf
                # Take a screenshot of the Robot image
                capture element Screenshot
                ...    xpath=//div[@id='robot-preview-image']
                ...    ${PDF_TEMP_OUTPUT_DIRECTORY}${/}${order}[Order number].png
                # Embed the robot screenshot to the receipt PDF file
                Open Pdf    ${PDF_TEMP_OUTPUT_DIRECTORY}${/}${order}[Order number].pdf
                ${files}    Create List
                ...    ${PDF_TEMP_OUTPUT_DIRECTORY}${/}${order}[Order number].pdf:1
                ...    ${PDF_TEMP_OUTPUT_DIRECTORY}${/}${order}[Order number].png:align=center
                Add Files To PDF
                ...    ${files}
                ...    ${PDF_TEMP_OUTPUT_DIRECTORY}${/}${order}[Order number].pdf
                Close Pdf
                # Order another Robot
                Click Button    order-another
                BREAK
            END
        END
    END

Close Multiple PDFs
    Close all pdfs

Create ZIP package from PDF files
    ${zip_file_name}    Set Variable    ${OUTPUT_DIRECTORY}${/}PDFs.zip
    Archive Folder With Zip
    ...    ${PDF_TEMP_OUTPUT_DIRECTORY}
    ...    ${zip_file_name}

Close the browser
    Close Browser

Cleanup temporary PDF directory
    Remove Directory    ${PDF_TEMP_OUTPUT_DIRECTORY}    True
