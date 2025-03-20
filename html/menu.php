<?php include('s3-conf.php'); ?>

<nav class="navbar navbar-default" role="navigation" style="background-color: LavenderBlush; height: 60px;">
    <div class="navbar-header">
        <a class="navbar-brand" href="/"><img height="38" src="<?php echo $linkestatico?>/<?php echo $bucket ?>/<?php echo $arqName ?>" /></a>
    </div>

    <div class="collapse navbar-collapse" id="bs-example-navbar-collapse-1">
        <ul class="nav navbar-nav">
            <li>
                <a href="index.php" style="color: SlateBlue;" onmouseover="this.style.color='blue'" onmouseout="this.style.color='SlateBlue'"><b>HOME</b></a>
            </li>
            <li>
                <a href="rds.php" style="color: SlateBlue;" onmouseover="this.style.color='blue'" onmouseout="this.style.color='SlateBlue'"><b>RDS</b></a>
            </li>
            <li>
                <a href="s3-input.php" style="color: SlateBlue;" onmouseover="this.style.color='blue'" onmouseout="this.style.color='SlateBlue'"><b>S3</b></a>
            </li>
            <li>
                <a href="imagem.php" style="color: SlateBlue;" onmouseover="this.style.color='blue'" onmouseout="this.style.color='SlateBlue'"><b>IMAGEM</b></a>
            </li>
        </ul>
    </div>
</nav>

