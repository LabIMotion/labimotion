# LabIMotion Changelog

## [2.0.0]
> 2025-03-25
* Features and enhancements:
  * Upgraded the main UI component, introducing a breaking change with react-bootstrap. Please note that this version is only compatible with ELN version using react-bootstrap v2.
  * Added new units ([#43](https://github.com/LabIMotion/labimotion/issues/43)).
  * Introduced a new form layout for **Designer**.
  * Introduced a new field type, `Select (Multiple)`, for **Designers**; the multiple selections feature is now supported.
  * Introduced the `Arrange Layers` and `Arrange Fields` feature for reordering the layers and fields.
  * Expanded the `LabIMotion Vocabulary (Lab-Vocab)`, more vocabularies are added.
  * Template version information is now available for **Users**.
  * Introduced the `Quick Filter` feature for **Designers**.
  * Set the first layer to be expanded by default for improved usability.
  * Added a feature allowing **User** to collapse or expand all layers with a single click.
  * Metadata Auto Mapper: Automatically prioritises the retrieval of parameters from Bruker's primary files.

  For more details, see the [Discussion](https://github.com/LabIMotion/labimotion/discussions/39).

  * LabIMotion Vocabulary (Lab-Vocab).
    * [Concept of LabIMotion Vocabulary (Lab-Vocab)](https://doi.org/10.5281/zenodo.13881070)
  * Standard Layer.
  * User Interface Foundation.
  * Extract "other solvent" for dataset.

  For more details, see the [Discussion](https://github.com/LabIMotion/labimotion/discussions/37).

* Bug fixes:
  * Fixed an issue where the links for `Drag Element` and `Drag Sample` would vanish. ([#42](https://github.com/LabIMotion/labimotion/issues/42))
  * Fixed an issue where the `Record Time` text would disappear. ([#40](https://github.com/LabIMotion/labimotion/issues/40))
  * Fixed an issue where an unexpected page was dislayed when no dataset existed for the CV case.
  * Fixed an issue where the selection was not working in the dataset after the library upgrade.
  * Fixed an issue where the new selection list does not immediately reflect in the table after the library upgrade.
  * Fixed a JavaScript warning related to the missing key prop for unique elements.

* Chores:
  * Updated library dependencies.

#### Note: The planned 1.5.0 release was postponed due to dependencies in a consuming project. All updates from 1.5.0 are included in 2.0.0, along with additional features and a breaking change.


## [1.4.1]
> 2024-10-24

* Bug fixes


## [1.4.0]
> 2024-08-22

* Features and enhancements:
  * **Preview image function for the “Upload” field type**: An image preview is provided once the uploaded file is an image. Furthermore, users can zoom in/out by changing the percentage, and the original file can be opened with one click. See the [idea](https://github.com/LabIMotion/labimotion/discussions/19) and a [visual demonstration](https://www.youtube.com/watch?v=FzNT2NSk_wc&feature=youtu.be).
  * **Labeling feature**: Allows users to add custom labels to elements for better organization and categorization. This feature enhances searchability and management within the system. See the [idea](https://github.com/LabIMotion/labimotion/discussions/28) and a [visual demonstration](https://www.youtube.com/watch?v=geuMQzN91aQ&feature=youtu.be).
  * **Drag reactions to elements**: Users can now drag and drop reactions onto elements, making the interface more interactive and intuitive. Consequently, the Export/Import Collection function and Reporting function will also include reaction data. See the [idea](https://github.com/LabIMotion/labimotion/discussions/22) and a [visual demonstration](https://www.youtube.com/watch?v=-oYkJaqhZPE).
  * **Change layer or field order via drag-and-drop**: Designers can rearrange layers or fields by simply dragging and dropping them into the desired order. This provides a more flexible and user-friendly way to manage data. A [visual demonstration](https://www.youtube.com/watch?v=V4nMukebAyA) is available.
  * **Custom flow**: Enables users to record their steps/work and visualize them as a flow diagram. A [video](https://www.youtube.com/watch?v=n6Q9sybhzmc) for your reference.


## [1.3.0]
> 2024-04-24

* Features and enhancements:
  * **Export/Import Collection function**: This function now includes self-designed elements within the same instance. See [discussion](https://github.com/LabIMotion/labimotion/discussions/15) for further details.
  * **Restriction Setting**: New restriction options are available, and you can also assign an alternative name for the field. Refer to the [discussion](https://github.com/LabIMotion/labimotion/discussions/8) for more information.
  * **Generic Element Split Function**: Introduce the 'Split' function, allowing users to split elements and establish parent-child relationships. Check [discussion](https://github.com/LabIMotion/labimotion/discussions/9) for more details.
  * **Generic Element Reporting Function**: This feature enables users to generate a basic report based on a generic element in docx format. Check [discussion](https://github.com/LabIMotion/labimotion/discussions/12) for more details. A [visual demonstration](https://youtu.be/XUbMF99Aku0) is available.
  * **System Units**: Additional system units are now supported. Click [here](https://github.com/LabIMotion/labimotion/wiki) to view the complete list.
  * **Customize Default Unit for Field**: As a Designer, you can set a preferred unit for a field as the default option within the template. A [visual demonstration](https://youtu.be/mEmDDS9z19s) is available.
  * Additional information has been added to the field header to provide designers with a quick overview.
* Bug fixes:
  * Resolved issue with importing segments.
  * Fixed issue where metadata download displayed labels instead of values.


## [1.1.4]
> 2024-02-15

* Bug fixes:
  * fix generic dataset general info for CV


## [1.1.3]
> 2024-01-31

* Upgrade ruby to 2.7.8


## [1.1.2]
> 2024-01-30

* Bug fixes:
  * fix: data cannot be removed from segment of element


## [1.1.1]
> 2024-01-16

* Bug fixes:
  * fix the zip upload issue


## [1.1.0]
> 2024-01-15

* “Dataset Excel” improvement - more information is provided in the `Description` sheet. See the documentation: [https://www.chemotion.net/docs/labimotion/guides/user/datasets/download].


## [1.0.18]
> 2023-10-30

* Initial version
* Generic Designer
* Workflow of Generic Element
* Repetitation of layers
* Drag Element to Element
* Dataset Metadata
* LabIMotion Template Hub Synchronization