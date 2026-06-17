import { LightningElement, api }
from 'lwc';

export default class FormField
    extends LightningElement {

    @api fieldConfig;

    @api currentValue;

    // PICKLIST

    get isPicklist() {

        const type =
            this.fieldConfig?.type
                ?.toLowerCase();

        return type === 'picklist'
            || type === 'dropdown';

    }

    // TEXTAREA

    get isTextarea() {

        return this.fieldConfig?.type
            ?.toLowerCase() === 'textarea';

    }

    // CHECKBOX

    get isCheckbox() {

        return this.fieldConfig?.type
            ?.toLowerCase() === 'checkbox';

    }

    // RADIO

    get isRadio() {

        return this.fieldConfig?.type
            ?.toLowerCase() === 'radio';

    }

    // STANDARD INPUTS

    get isStandardInput() {

        return [

            'text',
            'email',
            'phone',
            'date',
            'number'

        ].includes(

            this.fieldConfig?.type
                ?.toLowerCase()

        );

    }

    get inputType() {

        return this.isPhoneLikeField
            ? 'phone'
            : this.fieldConfig?.type;

    }

    get isPhoneLikeField() {

        const type =
            this.fieldConfig?.type
                ?.toLowerCase();

        const label =
            String(
                this.fieldConfig?.label || ''
            ).toLowerCase();

        return type === 'phone' ||
            label.includes('phone') ||
            label.includes('mobile') ||
            label.includes('telephone');

    }

    get hasSourceFields() {

        return this.fieldConfig?.isMergedAnswer === true &&
            this.sourceFields.length > 1;

    }

    get sourceFields() {

        let sourceText =
            this.fieldConfig?.sourceFieldsText || '';

        if (

            typeof sourceText === 'string' &&
            sourceText.trim().startsWith(
                '['
            )

        ) {

            try {

                const parsedSourceFields =
                    JSON.parse(
                        sourceText
                    );

                if (

                    Array.isArray(
                        parsedSourceFields
                    )

                ) {

                    sourceText =
                        parsedSourceFields.join(
                            ','
                        );

                }

            } catch (error) {

                sourceText =
                    this.fieldConfig?.sourceFieldsText || '';

            }

        }

        return sourceText
            .split(',')
            .map(sourceField => this.normalizeSourceField(sourceField))
            .filter(sourceField => {

                const lowerSource =
                    sourceField.toLowerCase();

                return sourceField &&
                    lowerSource !== 'prompt builder' &&
                    lowerSource !== 'einstein prompt builder' &&
                    lowerSource !== 'applicant knowledge' &&
                    lowerSource !== 'ai' &&
                    lowerSource !== 'chat prompt' &&
                    !lowerSource.includes(
                        'prompt builder'
                    ) &&
                    !lowerSource.includes(
                        'openai semantic extraction'
                    );

            });

    }

    normalizeSourceField(sourceField) {

        return String(
            sourceField || ''
        )
            .replace(/^fields merged:\s*/i, '')
            .replace(/^combined from:\s*/i, '')
            .replace(/^extracted from:\s*/i, '')
            .replace(/^fetched from:\s*/i, '')
            .trim();

    }

    get sourceFieldsText() {

        return this.sourceFields.join(
            ', '
        );

    }

    get sourceFieldsLabel() {

        return 'Fields merged';

    }

    get hasAIConfidence() {

        return this.normalizedAIConfidence !== null;

    }

    get normalizedAIConfidence() {

        const rawConfidence =
            this.fieldConfig?.aiConfidence;

        if (

            rawConfidence === null ||
            rawConfidence === undefined ||
            rawConfidence === ''

        ) {

            return null;

        }

        const confidence =
            Number(
                rawConfidence
            );

        if (

            Number.isNaN(
                confidence
            )

        ) {

            return null;

        }

        if (

            confidence <= 1

        ) {

            return Math.max(
                0,
                Math.min(
                    100,
                    Math.round(
                        confidence * 100
                    )
                )
            );

        }

        return Math.max(
            0,
            Math.min(
                100,
                Math.round(
                    confidence
                )
            )
        );

    }

    get confidencePercent() {

        return `${this.normalizedAIConfidence}%`;

    }

    get confidenceTooltip() {

        return `AI confidence: ${this.confidencePercent}`;

    }

    // OPTIONS

    get options() {

        // NO OPTIONS

        if (

            !this.fieldConfig ||

            !this.fieldConfig.options

        ) {

            return [];

        }

        // ALREADY OBJECT FORMAT

        if (

            Array.isArray(
                this.fieldConfig.options
            ) &&

            typeof this.fieldConfig.options[0]
                === 'object'

        ) {

            return this.fieldConfig.options;

        }

        // STRING ARRAY FORMAT

        return this.fieldConfig.options.map(option => {

            return {

                label: option,

                value: option

            };

        });

    }

    // REGEX VALIDATION

    get validationPattern() {

        return this.fieldConfig?.validationRule

            ? new RegExp(

                this.fieldConfig.validationRule

            )

            : null;

    }

    // INPUT CHANGE

    handleInputChange(event) {

        let val;

        // CHECKBOX

        if (this.isCheckbox) {

            val = event.target.checked;

        }

        else {

            val = event.target.value;

        }

        // TRIM STRINGS

        if (typeof val === 'string') {

            val = val.trim();

        }

        if (this.isPhoneLikeField) {

            val = String(val || '')
                .replace(/,/g, '')
                .trim();

        }

        this.emitValue(val);

    }

    // RADIO CHANGE

    handleRadioChange(event) {

        this.emitValue(event.detail.value);

    }

    // PICKLIST CHANGE

    handlePicklistChange(event) {

        this.emitValue(event.detail.value);

    }

    // BLUR VALIDATION

    handleBlur() {

        const inputElement =

            this.template.querySelector(
                '.input-node'
            );

        if (inputElement) {

            let value =
                inputElement.value;

            // REGEX CHECK

            if (

                this.validationPattern &&
                value &&
                !this.validationPattern.test(value)

            ) {

                inputElement.setCustomValidity(
                    'Invalid format'
                );

            }

            else {

                inputElement.setCustomValidity('');

            }

            inputElement.reportValidity();

        }

        this.dispatchEvent(

            new CustomEvent('fieldblur', {

                bubbles: true,

                composed: true

            })

        );

    }

    // SEND VALUE

    emitValue(value) {

        this.dispatchEvent(

            new CustomEvent('valuechange', {

                detail: {

                    questionId:
                        this.fieldConfig.id,

                    value: value

                }

            })

        );

    }

    // VALIDATE

    @api
    validate() {

        const inputElement =

            this.template.querySelector(
                '.input-node'
            );

        if (!inputElement) {

            return true;

        }

        let value =
            inputElement.value;

        // REGEX VALIDATION

        if (

            this.validationPattern &&
            value &&
            !this.validationPattern.test(value)

        ) {

            inputElement.setCustomValidity(
                'Invalid format'
            );

        }

        else {

            inputElement.setCustomValidity('');

        }

        inputElement.reportValidity();

        return inputElement.checkValidity();

    }

}
