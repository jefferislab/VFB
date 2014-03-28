#!/bin/bash
#Called from deployment scripts
if [ -d .git ] && [ $branch ]
then
    nice ssh-agent bash -c 'ssh-add /disk/data/Home/$USER/.ssh/id_dsa; git pull origin $branch'
#    test and add git server filters if required.
    if [ ! -f .git/info/attributes ]
    then
        echo "Adding git Smudge/Clean filters..."
        cp deploy/config .git/
        if [ ! -d .git/info ]
        then
            mkdir .git/info
        fi
        cp deploy/attributes .git/info/
        sed -i s/BRANCH_NAME/${branch}/g .git/config
    else
        echo 'Git Smudge/Clean filters already added.' 
        echo 'Note: to manually modify, use instructions in filters folder, only if a change is required'
    fi

    if [ `git whatchanged --pretty="format:" --name-only --since="10 minutes ago" | grep "\.gz" | wc -l` -gt 0 ]
    then
        nice deploy/decompress.sh
    fi
    
    echo "recording git branch and version details"
    git describe --long > revision
    echo $branch > branch
    cp /disk/data/VFB/Chado/VFB_DB/current/revision flybase
    echo "which are:"
    cat branch
    cat revision
    echo "Flybase version:"
    cat flybase
    echo "checking filters to use correct branch names"
    find filters/ -name 'Filt*Smudge.sed' | xargs sed -i -f filters/Local-General-Clean.sed
    find filters/ -name 'Filt*Smudge.sed' | xargs sed -i -f filters/Local-${branch}-Smudge.sed
    if [ `git whatchanged --pretty="format:" --name-only --since="10 minutes ago" | grep "tiledImageModelD" | wc -l` -gt 0 ]
    then
        echo "checking image json files"
        find data/flybrain/ -name 'tiledImageModelD*.jso' | xargs sed -i -f filters/FiltTiledImageModelDataClean.sed
        find data/flybrain/ -name 'tiledImageModelD*.jso' | xargs sed -i -f filters/FiltTiledImageModelDataSmudge.sed
    fi
    if [ `git whatchanged --pretty="format:" --name-only --since="10 minutes ago" | grep "resources.properties" | wc -l` -gt 0 ]
    then
        echo "checking resources.properties"
        find src/ -name 'resources.properties' | xargs sed -i -f filters/FiltResPropClean.sed  
        find src/ -name 'resources.properties' | xargs sed -i -f filters/FiltResPropSmudge.sed  
    fi
    if [ `git whatchanged --pretty="format:" --name-only --since="10 minutes ago" | grep "web.xml" | wc -l` -gt 0 ]
    then
        echo "checking web.xml"
        find WEB-INF -name 'web.xml' | xargs sed -i -f filters/FiltWebXmlClean.sed
        find WEB-INF -name 'web.xml' | xargs sed -i -f filters/FiltWebXmlSmudge.sed
    fi
    if [ `git whatchanged --pretty="format:" --name-only --since="10 minutes ago" | grep "ga.jsp" | wc -l` -gt 0 ]
    then
        echo "checking google analytics code"
        find jsp/ -name 'ga.jsp' | xargs sed -i -f filters/FiltGoogleAnClean.sed
        find jsp/ -name 'ga.jsp' | xargs sed -i -f filters/FiltGoogleAnSmudge.sed
    fi
    if [ `git whatchanged --pretty="format:" --name-only --since="10 minutes ago" | grep "\.xml\|\.jsp\|\.htm\|\.html\|\.js\|\.owl" | wc -l` -gt 0 ]
    then
        echo "checking any direct references to website url is set to the branch site"
        find ./ -name 's*.xml' -or -name '*.jsp' -or -name '*.htm' -or -name '*.html' -or -name '*.js' -or -name '*.owl' | xargs sed -i -f filters/FiltGenClean.sed
        find ./ -name 's*.xml' -or -name '*.jsp' -or -name '*.htm' -or -name '*.html' -or -name '*.js' -or -name '*.owl' | xargs sed -i -f filters/FiltGenSmudge.sed 
    fi
    if [ `git whatchanged --pretty="format:" --name-only --since="10 minutes ago" | grep "src/" | wc -l` -gt 0 ]
    then
        echo "Recompiling the site..."
        nice ant
    fi
    if [ `git whatchanged --pretty="format:" --name-only --since="10 minutes ago" | grep "\.owl" | wc -l` -gt 0 ]
    then
        echo "Redeploying ontology server..."
        nice deploy/start-${branch}-Ont-Server.sh
    fi
    echo "Done."
else
    echo "Error: Git directory not found! This script should be run in the git base directory e.g. /disk/data/tomcat/fly/webapps/vfb?/"
fi
    
