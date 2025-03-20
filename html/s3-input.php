<!DOCTYPE html>
<html>
  <head>
    <title>AWS Cloud Practioner Essentials</title>
    <link href="css/bootstrap.min.css" rel="stylesheet">
    <link href="css/style.css" rel="stylesheet">
  </head>

  <body>
    <div class="container">

	<div class="row">
		<div class="col-md-12">
      <?php include('menu.php'); ?>




   <div  class="container" style="width: 100%; border-radius: 3px; background-color:#eee; margin-top: 20px; color:#fff">
      
            <div class="form-group">
       
      
    </div>
    <div class="navbar-header" >
     
        
    </div>
   <form name="input" style="width: 90%;" action="s3-write-config.php" method="post" class="form-horizontal">
  <div class="form-group" style="margin-top: 20px;" >
    <div class="col-sm-10">
    </div>
  </div>

  <div class="form-group">
    <label for="database" class="col-sm-2 control-label" style="color:#333">Bucket</label>
    <div class="col-sm-10">
      <input type="text" class="form-control" name="database">
    </div>
  </div>

  <div class="form-group">
    <label for="regiao" class="col-sm-2 control-label" style="color:#333">Região</label>
    <div class="col-sm-10">
      <input type="text" class="form-control" name="regiao">
    </div>
  </div>

  <div class="form-group">
    <label for="username" class="col-sm-2 control-label" style="color:#333">acck</label>
    <div class="col-sm-10">
      <input type="text" class="form-control" name="username">
    </div>
  </div>

  <div class="form-group">
    <label for="password" class="col-sm-2 control-label" style="color:#333">scck</label>
    <div class="col-sm-10">
      <input type="password" class="form-control" name="password">
    </div>
  </div>

  <div class="form-group">
    <div class="col-sm-offset-2 col-sm-10">
      <input class="btn btn-primary btn-sm" type="submit" class="btn btn-default"/>
    </div>
  </div>
</form>
 

	</div>
  </div>
</div>
</div>

<script src="js/jquery.min.js"></script>
<script src="js/bootstrap.min.js"></script>
<script src="js/scripts.js"></script>

</body>
</html>
