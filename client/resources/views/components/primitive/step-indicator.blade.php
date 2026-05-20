@props([
    'totalSteps'     => 1,
    'currentStep'    => 1,
    'completedSteps' => [],
    'size'           => 'Default',
])

@php
    $classes = cva('StepIndicator', [
        'variants' => [
            'size' => [
                'Default' => 'StepIndicator--size-default',
                'Small'   => 'StepIndicator--size-small',
            ],
        ],
        'defaultVariants' => ['size' => 'Default'],
    ], ['size' => $size]);
@endphp

<div {{ $attributes->merge(['class' => $classes]) }}>
    @for($step = 1; $step <= $totalSteps; $step++)
        @php
            $isCompleted = in_array($step, $completedSteps);
            $isActive    = $step === $currentStep;
            $isPast      = $step < $currentStep;
            $isComplete  = count($completedSteps) > 0 ? $isCompleted : $isPast;

            $stepClasses = 'StepIndicator__step';
            if ($isComplete) $stepClasses .= ' StepIndicator__step--complete';
            if ($isActive)   $stepClasses .= ' StepIndicator__step--active';
        @endphp
        <div class="{{ $stepClasses }}"></div>
    @endfor
</div>
