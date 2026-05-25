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