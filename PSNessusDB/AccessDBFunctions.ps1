function run-AccessNoQuery {
    param ( 
     [string]$sql, 
     [System.Data.OleDb.OleDbConnection]$connection 
    ) 
        $cmd = New-Object System.Data.OleDb.OleDbCommand($sql, $connection) 
        $cmd.ExecuteNonQuery() 
}

function Get-AccessData { 
param ( 
    [string]$sql, 
    [System.Data.OleDb.OleDbConnection]$connection, 
    [switch]$grid 
) 
    
    $cmd = New-Object System.Data.OleDb.OleDbCommand($sql, $connection) 
    $reader = $cmd.ExecuteReader() 
    
    $dt = New-Object System.Data.DataTable 
    $dt.Load($reader) 
    
    if ($grid) {$dt | Out-GridView -Title "$sql" } 
    else {$dt} 

}  

function add-AccessData([String]$table, [Array]$Param, [Array]$Values, [System.Data.OleDb.OleDbConnection]$connection){
    $return = "INSERT INTO $table ("
    for ($j=0; $j -lt $Param.count; $j++){
        $return += "[$($Param[$j])]"
        if ( $j -lt ($Param.count-1) ){
            $return += ', '
        }
    } 
    $return += ") VALUES ("
    for ($j=0; $j -lt $Values.count; $j++){
        $return += "'"
        $return += $Values[$j]
        $return += "'"
        if ( $j -lt ($Values.count-1)){
            $return += ', '
        }
    } 
    $return += ")"
        
    try{
        $cmd = New-Object System.Data.OleDb.OleDbCommand($return, $connection) 
        $iAffected = $cmd.ExecuteNonQuery()
        $cmd2 = New-Object System.Data.OleDb.OleDbCommand("SELECT @@IDENTITY;", $connection)
        [int]$recordID = $cmd2.ExecuteScalar()
    }
    catch{
        Write-Warning "Error Adding Access Data:"
        write-Host ""
        Write-Warning "   ERROR: $_.Exception.Message"
        for ($j=0; $j -lt $Param.count; $j++){
            Write-Host "   [$($Param[$j])]: $($Values[$j])"
        }
    }
    
    $recordID
}

function fix-SQLColumns([String]$table, [Array]$Columns, [Array]$Values, [System.Data.OleDb.OleDbConnection]$connection){
    
    $connColumns = $connection.GetSchema("columns") | where-object{$_.TABLE_NAME -eq $table} | foreach{$_.COLUMN_NAME}
    
    for ($j=0; $j -lt $Columns.count; $j++){
        if (($connColumns -contains $columns[$j]) -ne $true){
            if($Values[$j] -gt 200)
            {     $sqlAlter = "ALTER TABLE $table ADD COLUMN [$($columns[$j])] MEMO"}
            else{ $sqlAlter = "ALTER TABLE $table ADD COLUMN [$($columns[$j])] TEXT(255)"}
            $cmdAdd = New-Object System.Data.OleDb.OleDbCommand($sqlAlter, $conn)
            $iAffected = $cmdAdd.ExecuteNonQuery()
        } 
    }
    
}

function get-SQLEscaping ([string]$sql){

# ' --> ''
    $sql = $sql.replace("`'", "`'`'")
# ? --> [?]
    $sql = $sql.replace("?", "`[?`]")
# * -->[*]
    $sql = $sql.replace("*", "`[*`]")
# # --> [#]
    $sql = $sql.replace("#", "`[#`]")
	
# NewLine Characters	
    $sql = $sql.replace("`n", "`r`n")
	$sql = $sql.replace("`r", "`r`n")
	$sql = $sql.replace("`r`n`r`n", "`r`n")
	$sql = $sql.replace("`r`n`r`n", "`r`n")
	do{
		$sql = $sql.TrimStart("`r")
		$sql = $sql.TrimStart("`n")
		$sql = $sql.Trim()
	} until (!($sql.startswith("`r") -or  $sql.startswith("`n") -or $sql.startswith(" ")))	
	
    return $sql
}

function update_or_create_by_id ([String]$table, [string]$ID, [Array]$Param, [Array]$Values,[System.Data.OleDb.OleDbConnection]$connection){
    $result = Get-AccessData "SELECT ID  from $table where ID = $id" $conn
    if ($result) {
    $sql = "UPDATE $table SET "
    for ($j=0; $j -lt $Param.count; $j++){
        $sql += "[$($Param[$j])] = '$($Values[$j])'"
        if ( $j -lt ($Param.count-1) ){
            $sql += ', '
        }
    } 
    $sql += "WHERE ID = $id;"
    $cmd = New-Object System.Data.OleDb.OleDbCommand($sql, $connection) 
    $cmd.ExecuteNonQuery()
    $id
    } else {
    
    add-AccessData $table $Param $Values $conn
    
    }
}

Function Check-Path($Path)
{
 If(!(Test-Path -path (Split-Path -path $Db -parent)))
   { 
     Throw "$(Split-Path -path $Db -parent) Does not Exist" 
   }
  ELSE
  { 
   If(Test-Path -Path $Db)
     {
      Throw "$db already exists"
     }
  }
} #End Check-Path

Function Create-Database($Db)
{
 $application = New-Object -ComObject Access.Application
 $application.NewCurrentDataBase($Db,12)
 $application.CloseCurrentDataBase()
 $application.Quit()
} #End Create-DataBase

Function Invoke-ADOCommand {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory=$True,
		ValueFromPipeline=$False)]
		[string[]]$Database,
		
		[Parameter(Mandatory=$True,
		ValueFromPipeline=$True)]
		[string[]]$command
	)
	BEGIN {
	$connection = New-Object -ComObject ADODB.Connection
 	$connection.Open("Provider= Microsoft.ACE.OLEDB.12.0;Data Source=$Database" )
 	}
	PROCESS {
		$connection.Execute($command) | out-null
	}
	END {$connection.Close()}
}
