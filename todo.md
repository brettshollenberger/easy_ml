# Refactor Preprocessing Steps

Currently, preprocessing steps was a JSON blob on the Column model.

It would be set like:

    @dataset.columns.find_by(name: "annual_revenue").update(
      preprocessing_steps: {
        inference: {
            method: :last
        },
        training: {
          method: :mean,
          params: {
            clip: {
              min: 0, max: 100
            }
          },
        }
      }],
    )
