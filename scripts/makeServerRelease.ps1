﻿param( 
    [string]$workingDir = 'C:\Devo\synapse\synapse.server.net\scripts'
)

function RemoveFile( $path )
{
    if( Test-Path $path )
    {
        Remove-Item( $path ) -Recurse
    }
}

function CleanFolder
{
    param( [string]$folder, [boolean]$core )

    RemoveFile( $folder + '\*.pd*' )
    RemoveFile( $folder + '\*.vshost.*' )
    RemoveFile( $folder + '\*.xml' )
    RemoveFile( $folder + '\*.zip' )
    RemoveFile( $folder + '\Synapse.Server.Install*' )
    RemoveFile( $folder + '\Synapse.Server.config.yaml' )
    if( $core )
    {
        RemoveFile( $folder + '\Synapse.Core.dll' )
        RemoveFile( $folder + '\YamlDotNet.dll' )
        RemoveFile( $folder + '\Synapse.Controller.Common.dll' )
        RemoveFile( $folder + '\System.Net.Http.Formatting.dll' )
        RemoveFile( $folder + '\System.Web.Http.dll' )
        RemoveFile( $folder + '\Newtonsoft.Json.dll' )
        RemoveFile( $folder + '\Suplex.Core.dll' )
    }
}

function CopyFolder( $source, $destination )
{
    New-Item $destination -Type directory | Out-Null
    $r = $dir.ToLower().Replace( '\scripts', $source )
    Copy-Item $r $destination -recurse
    CleanFolder $destination $true
}

function Unzip( $source, $destination )
{
    [io.compression.zipfile]::ExtractToDirectory( $source, $destination )
}

function DownloadRelease( $repo, $destination )
{
    Write-Host ("Downloading: " + $repo)
    $uri = ('https://api.github.com/repos/synapseproject/' + $repo + '/releases')
    $rel = Invoke-WebRequest -Uri $uri | ConvertFrom-Json
    $url = $rel[0].assets[0].browser_download_url
    $name = $dir + '\' + $rel[0].assets[0].name

    (New-Object System.Net.WebClient).DownloadFile( $url, $name )

    Unzip $name $destination
    CleanFolder $destination $true

    Remove-Item $name
}

function GetSynapseCli( $destination )
{
    $cli = ($dir + '\cli')
    DownloadRelease 'synapse.core.net' $cli
    Move-Item ($cli + '\synapse.cli.exe') $destination -Force
    RemoveFile( $cli + '\*' );
    Remove-Item $cli
}

function GetVersionInfo( $folder )
{
    return [System.Diagnostics.FileVersionInfo]::GetVersionInfo($folder + '\Synapse.Server.exe').FileVersion
}

function MakeServerRelease()
{
    $release = 'Release';
    $fr = ($dir + '\' + $release)

    if( Test-Path( $release ) )
    {
        RemoveFile( $fr + '\*' );
        Remove-Item $release
    }

    #copy Release folder
    $r = $dir.ToLower().Replace( '\scripts', '\Synapse.Server\bin\Release')
    Copy-Item $r $dir -recurse
    CleanFolder $release $false
    Unzip ($dir + '\_setup.zip') $fr

    #delete any existing folders from Release
    Get-ChildItem $release -directory | ForEach-Object { Remove-Item -recurse -force ( $release + '\' + $_ ) }

    #these folders are created as empty
    Write-Host "Creating folders."
    New-Item ($release + '\Assemblies') -Type directory | Out-Null
    New-Item ($release + '\Logs') -Type directory | Out-Null
    New-Item ($release + '\Crypto') -Type directory | Out-Null

    #authentication folder
    Write-Host "Copying Authentication release files."
    CopyFolder '\Synapse.Authentication\bin\Release\*' ($release + '\Authentication')

    #dal folder
    Write-Host "Creating DAL folders, copying DAL release files."
    CopyFolder '\Synapse.Controller.Dal.FileSystem\bin\Release\*' ($release + '\Dal')
    New-Item ($release + '\Dal\History') -Type directory | Out-Null
    New-Item ($release + '\Dal\Plans') -Type directory | Out-Null
    New-Item ($release + '\Dal\Security') -Type directory | Out-Null
    Write-Host "Unzipping sample Plans and Suplex."
    Unzip ($dir + '\_Plans.zip') ($fr + '\Dal')
    Unzip ($dir + '\_Suplex.zip') ($fr + '\Dal\Security')

    #handlers folder
    Write-Host "Creating Handlers folders."
    $handlers = ($fr + '\Handlers')
    New-Item  $handlers -Type directory | Out-Null
    DownloadRelease 'handlers.CommandLine.net' $handlers
    DownloadRelease 'handlers.Sql.net' $handlers
    DownloadRelease 'handlers.ActiveDirectory.net' $handlers

    #GetSynapseCli...
    GetSynapseCli $fr

    #zip the Release folder
    Write-Host "Creating Release zip."
    $ver = GetVersionInfo $fr
    $archive = ($dir + '\Synapse.Server.' + $ver + '-beta.zip')
    RemoveFile $archive
    [io.compression.zipfile]::CreateFromDirectory( $fr, $archive, [System.IO.Compression.CompressionLevel]::Optimal, $false );

    #clean up
    Write-Host "Deleting temp files."
    RemoveFile( $fr + '\*' );
    Remove-Item $release
}


Add-Type -assembly "system.io.compression.filesystem"

$dir = $workingDir
Set-Location $dir

MakeServerRelease