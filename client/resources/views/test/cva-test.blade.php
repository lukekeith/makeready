{{-- Test view used by ComponentSmokeTest to verify cva() works in Blade context --}}
<!DOCTYPE html>
<html>
<head><title>CVA Test</title></head>
<body>
    <div class="{{ cva('Button', ['variants' => ['variant' => ['Primary' => 'Button--primary', 'Secondary' => 'Button--secondary']]], ['variant' => 'Primary']) }}">
        Primary Button
    </div>
    <div class="{{ cva('Badge', ['variants' => ['variant' => ['Default' => 'Badge--default']], 'defaultVariants' => ['variant' => 'Default']], []) }}">
        Default Badge
    </div>
    <div class="{{ cva('Icon', []) }}">
        Icon
    </div>
</body>
</html>
